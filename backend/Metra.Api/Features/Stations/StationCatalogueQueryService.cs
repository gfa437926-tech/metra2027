namespace Metra.Api.Features.Stations;

/// <summary>
/// Source classification is evidence about the source collection, not a claim
/// that two records from different sources are the same physical station.
/// </summary>
public enum StationCatalogueSourceKind
{
    Classic = 0,
    Automatic = 1
}

public sealed record StationCatalogueQuery(
    StationCatalogueSourceKind? SourceKind = null,
    string? NamePrefix = null,
    int PageSize = 50,
    string? Cursor = null);

/// <summary>
/// Source-preserving station projection. CanonicalStationId is intentionally
/// absent until an owner-approved crosswalk establishes canonical identity.
/// Coordinates and elevation remain nullable when the source has no verified
/// value. SourceStationType preserves raw source metadata without interpreting it.
/// </summary>
public sealed record StationCatalogueItem(
    StationCatalogueSourceKind SourceKind,
    string SourceRecordId,
    string DisplayName,
    string? SourceStationType,
    string? SourceCode,
    decimal? Latitude,
    decimal? Longitude,
    decimal? ElevationMetres);

public sealed record StationCatalogueStorePage(
    IReadOnlyList<StationCatalogueItem> Items,
    bool HasMore,
    string? NextCursor);

public sealed record StationCataloguePage(
    IReadOnlyList<StationCatalogueItem> Items,
    bool HasMore,
    string? NextCursor);

public enum StationCatalogueReadStatus
{
    Succeeded = 0,
    Unauthenticated = 1,
    Unauthorized = 2,
    InvalidQuery = 3,
    InvalidStoreResponse = 4
}

public sealed record StationCatalogueReadResult(
    StationCatalogueReadStatus Status,
    StationCataloguePage? Page = null)
{
    public bool Succeeded => Status == StationCatalogueReadStatus.Succeeded;
}

/// <summary>
/// Trusted source boundary. Implementations may read the classic and automatic
/// sources independently and return a unified, source-preserving projection.
/// They must not deduplicate by name, synthesize coordinates, or infer a
/// canonical station ID. Every page must enforce the approved catalogue-read
/// permission. Cursor integrity must be validated and bound to actor and filters.
/// Use deterministic ordering SourceKind ASC, SourceRecordId ASC.
/// </summary>
public interface IStationCatalogueReadStore
{
    Task<StationCatalogueStorePage> ReadPageAsync(
        string actorUserId,
        StationCatalogueQuery normalizedQuery,
        CancellationToken cancellationToken);
}

/// <summary>
/// Read-only station catalogue query. Identity comes from the authenticated
/// server context; authorization is re-evaluated by the trusted store per page.
/// </summary>
public sealed class StationCatalogueQueryService(
    Metra.Api.Features.Identity.IAccountLifecycleActorContextProvider actorContextProvider,
    IStationCatalogueReadStore store)
{
    private const int MaximumPageSize = 100;
    private const int MaximumCursorLength = 2048;
    private const int MaximumNamePrefixLength = 128;
    private const int MaximumSourceRecordIdLength = 128;
    private const int MaximumDisplayNameLength = 256;

    public async Task<StationCatalogueReadResult> ReadAsync(
        StationCatalogueQuery? query,
        CancellationToken cancellationToken = default)
    {
        if (query is null ||
            query.PageSize is < 1 or > MaximumPageSize ||
            query.Cursor?.Length > MaximumCursorLength ||
            (query.SourceKind is { } kind && !Enum.IsDefined(kind)))
            return InvalidQuery();

        var prefix = NormalizeNamePrefix(query.NamePrefix);
        if (query.NamePrefix is not null && prefix is null)
            return InvalidQuery();

        var cursor = string.IsNullOrWhiteSpace(query.Cursor) ? null : query.Cursor;
        if (cursor?.Any(char.IsControl) == true)
            return InvalidQuery();

        var actorUserId = await actorContextProvider.GetCurrentActorUserIdAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(actorUserId))
            return new(StationCatalogueReadStatus.Unauthenticated);
        if (!IsCanonicalIdentifier(actorUserId))
            return new(StationCatalogueReadStatus.Unauthorized);

        var normalized = new StationCatalogueQuery(query.SourceKind, prefix, query.PageSize, cursor);
        var page = await store.ReadPageAsync(actorUserId, normalized, cancellationToken);
        if (!IsValidPage(page, normalized))
            return new(StationCatalogueReadStatus.InvalidStoreResponse);

        return new(StationCatalogueReadStatus.Succeeded,
            new(Array.AsReadOnly(page.Items.ToArray()), page.HasMore, page.NextCursor));
    }

    private static bool IsValidPage(StationCatalogueStorePage? page, StationCatalogueQuery query)
    {
        if (page?.Items is null ||
            page.Items.Count > query.PageSize ||
            (page.HasMore && page.Items.Count == 0) ||
            page.HasMore != !string.IsNullOrWhiteSpace(page.NextCursor) ||
            page.NextCursor?.Length > MaximumCursorLength ||
            page.NextCursor?.Any(char.IsControl) == true ||
            (page.NextCursor is not null &&
             string.Equals(page.NextCursor, query.Cursor, StringComparison.Ordinal)))
            return false;

        StationCatalogueItem? previous = null;
        var seen = new HashSet<(StationCatalogueSourceKind Kind, string Id)>();
        foreach (var item in page.Items)
        {
            if (item is null ||
                !Enum.IsDefined(item.SourceKind) ||
                (query.SourceKind is { } kind && item.SourceKind != kind) ||
                !IsCanonicalIdentifier(item.SourceRecordId) ||
                item.DisplayName is null ||
                string.IsNullOrWhiteSpace(item.DisplayName) ||
                item.DisplayName.Length > MaximumDisplayNameLength ||
                item.DisplayName.Any(char.IsControl) ||
                (query.NamePrefix is { } prefix &&
                 !item.DisplayName.StartsWith(prefix, StringComparison.Ordinal)) ||
                !IsOptionalTextValid(item.SourceStationType, 128) ||
                !IsOptionalTextValid(item.SourceCode, 128) ||
                !IsCoordinatePairValid(item.Latitude, item.Longitude) ||
                (item.ElevationMetres is { } elevation && elevation is < -500m or > 10000m) ||
                !seen.Add((item.SourceKind, item.SourceRecordId)))
                return false;

            if (previous is not null && Compare(previous, item) >= 0)
                return false;
            previous = item;
        }

        return true;
    }

    private static int Compare(StationCatalogueItem left, StationCatalogueItem right)
    {
        var kind = left.SourceKind.CompareTo(right.SourceKind);
        return kind != 0
            ? kind
            : string.CompareOrdinal(left.SourceRecordId, right.SourceRecordId);
    }

    private static bool IsCoordinatePairValid(decimal? latitude, decimal? longitude)
    {
        if (latitude is null || longitude is null)
            return latitude is null && longitude is null;
        return latitude is >= -90m and <= 90m &&
               longitude is >= -180m and <= 180m;
    }

    private static bool IsOptionalTextValid(string? value, int maxLength)
        => value is null ||
           (value.Length <= maxLength && !value.Any(char.IsControl));

    private static string? NormalizeNamePrefix(string? value)
    {
        if (value is null || value.Any(char.IsControl))
            return null;

        var normalized = value.Trim();
        return normalized.Length is > 0 and <= MaximumNamePrefixLength
            ? normalized
            : null;
    }

    private static bool IsCanonicalIdentifier(string value)
        => !string.IsNullOrWhiteSpace(value) &&
           value.Length <= MaximumSourceRecordIdLength &&
           value == value.Trim() &&
           value.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_' or '.' or ':');

    private static StationCatalogueReadResult InvalidQuery()
        => new(StationCatalogueReadStatus.InvalidQuery);
}
