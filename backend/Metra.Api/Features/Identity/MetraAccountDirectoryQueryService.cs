using Metra.Api.Domain.Identity;

namespace Metra.Api.Features.Identity;

/// <summary>
/// Bounded, read-only account directory filters. AccountIdPrefix is an exact
/// canonical prefix filter; it is not a free-text search expression.
/// </summary>
public sealed record MetraAccountDirectoryQuery(
    MetraAccountAccessState? State = null,
    string? StationId = null,
    string? AccountIdPrefix = null,
    int PageSize = 50,
    string? Cursor = null);

/// <summary>
/// Deliberately minimal directory projection. Profile/contact data, Auth subjects,
/// permission facts and audit payloads are not exposed by this listing contract.
/// </summary>
public sealed record MetraAccountDirectoryItem(string AccountId, MetraAccountAccessState State);

public sealed record MetraAccountDirectoryStorePage(
    IReadOnlyList<MetraAccountDirectoryItem> Items, bool HasMore, string? NextCursor);

public sealed record MetraAccountDirectoryPage(
    IReadOnlyList<MetraAccountDirectoryItem> Items, bool HasMore, string? NextCursor);

public enum MetraAccountDirectoryReadStatus
{
    Succeeded = 0, Unauthenticated = 1, Unauthorized = 2,
    InvalidQuery = 3, InvalidStoreResponse = 4
}

public sealed record MetraAccountDirectoryReadResult(
    MetraAccountDirectoryReadStatus Status, MetraAccountDirectoryPage? Page = null)
{
    public bool Succeeded => Status == MetraAccountDirectoryReadStatus.Succeeded;
}

/// <summary>
/// Trusted store boundary. Every page must independently enforce the approved
/// account-directory permission and the actor's authoritative station scope.
/// A requested StationId narrows visibility; it must never widen it. Validate
/// cursor integrity and bind it to actor identity plus all normalized filters.
/// Use keyset ordering AccountId ASC and apply the prefix as a literal prefix,
/// not as a SQL wildcard or expression. Never trust client-provided scope facts.
/// </summary>
public interface IMetraAccountDirectoryReadStore
{
    Task<MetraAccountDirectoryStorePage> ReadPageAsync(
        string actorUserId, MetraAccountDirectoryQuery normalizedQuery,
        CancellationToken cancellationToken);
}

/// <summary>
/// Read-only account directory application service. Actor identity is obtained
/// from the authenticated server request. The store remains the authorization
/// authority and must re-check permission/scope for every page.
/// </summary>
public sealed class MetraAccountDirectoryQueryService(
    IAccountLifecycleActorContextProvider actorContextProvider,
    IMetraAccountDirectoryReadStore store)
{
    private const int MaximumPageSize = 100;
    private const int MaximumCursorLength = 2048;
    private const int MaximumIdentifierLength = 128;

    public async Task<MetraAccountDirectoryReadResult> ReadAsync(
        MetraAccountDirectoryQuery? query, CancellationToken cancellationToken = default)
    {
        if (query is null || query.PageSize is < 1 or > MaximumPageSize ||
            query.Cursor?.Length > MaximumCursorLength ||
            (query.State is { } state && !Enum.IsDefined(state)))
            return InvalidQuery();

        var stationId = NormalizeIdentifierFilter(query.StationId);
        var prefix = NormalizeIdentifierFilter(query.AccountIdPrefix);
        if ((query.StationId is not null && stationId is null) ||
            (query.AccountIdPrefix is not null && prefix is null))
            return InvalidQuery();

        var cursor = string.IsNullOrWhiteSpace(query.Cursor) ? null : query.Cursor;
        if (cursor?.Any(char.IsControl) == true)
            return InvalidQuery();

        var actorUserId = await actorContextProvider.GetCurrentActorUserIdAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(actorUserId))
            return new(MetraAccountDirectoryReadStatus.Unauthenticated);
        if (!IsIdentifier(actorUserId))
            return new(MetraAccountDirectoryReadStatus.Unauthorized);

        var normalized = new MetraAccountDirectoryQuery(
            query.State, stationId, prefix, query.PageSize, cursor);
        var page = await store.ReadPageAsync(actorUserId, normalized, cancellationToken);
        if (!IsValidPage(page, normalized))
            return new(MetraAccountDirectoryReadStatus.InvalidStoreResponse);

        return new(MetraAccountDirectoryReadStatus.Succeeded,
            new(Array.AsReadOnly(page.Items.ToArray()), page.HasMore, page.NextCursor));
    }

    private static bool IsValidPage(
        MetraAccountDirectoryStorePage? page, MetraAccountDirectoryQuery query)
    {
        if (page?.Items is null || page.Items.Count > query.PageSize ||
            (page.HasMore && page.Items.Count == 0) ||
            page.HasMore != !string.IsNullOrWhiteSpace(page.NextCursor) ||
            page.NextCursor?.Length > MaximumCursorLength ||
            page.NextCursor?.Any(char.IsControl) == true ||
            (page.NextCursor is not null &&
             string.Equals(page.NextCursor, query.Cursor, StringComparison.Ordinal)))
            return false;

        string? previousId = null;
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var item in page.Items)
        {
            if (item is null || !IsIdentifier(item.AccountId) ||
                !Enum.IsDefined(item.State) ||
                (query.State is { } state && item.State != state) ||
                (query.AccountIdPrefix is { } prefix &&
                 !item.AccountId.StartsWith(prefix, StringComparison.Ordinal)) ||
                !seen.Add(item.AccountId) ||
                (previousId is not null &&
                 string.CompareOrdinal(previousId, item.AccountId) >= 0))
                return false;
            previousId = item.AccountId;
        }
        return true;
    }

    private static string? NormalizeIdentifierFilter(string? value)
    {
        if (value is null) return null;
        var normalized = value.Trim();
        return IsIdentifier(normalized) ? normalized : null;
    }

    private static bool IsIdentifier(string value)
        => !string.IsNullOrWhiteSpace(value) && value.Length <= MaximumIdentifierLength &&
           value == value.Trim() &&
           value.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_' or '.' or ':');

    private static MetraAccountDirectoryReadResult InvalidQuery()
        => new(MetraAccountDirectoryReadStatus.InvalidQuery);
}
