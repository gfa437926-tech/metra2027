using System.Security.Cryptography;
using System.Text.Json;

namespace Metra.Api.Features.Observations;

public sealed record HourlyObservationQueueQuery(
    string? StationId = null,
    int PageSize = 50,
    string? Cursor = null);

public sealed record HourlyObservationQueueItem(
    string ObservationId,
    string StationId,
    DateOnly ObservationDate,
    int UtcHour,
    string SubmittedBy,
    DateTimeOffset SubmittedAtUtc);

public sealed record HourlyObservationQueueStorePage(
    IReadOnlyList<HourlyObservationQueueItem> Items,
    bool HasMore,
    string? NextCursor);

public sealed record HourlyObservationQueuePage(
    IReadOnlyList<HourlyObservationQueueItem> Items,
    bool HasMore,
    string? NextCursor);

public enum HourlyObservationQueueReadStatus
{
    Succeeded = 0,
    Unauthenticated = 1,
    Unauthorized = 2,
    InvalidQuery = 3,
    InvalidStoreResponse = 4
}

public sealed record HourlyObservationQueueReadResult(
    HourlyObservationQueueReadStatus Status,
    HourlyObservationQueuePage? Page = null)
{
    public bool Succeeded => Status == HourlyObservationQueueReadStatus.Succeeded;
}

public sealed class HourlyObservationQueueInvalidCursorException : Exception { }

/// <summary>
/// The store must revalidate the actor's active account, review permission and
/// station assignments against authoritative tables for every read. Returned
/// rows are limited to pending observations within those station assignments.
/// Pagination must use the stable descending (submitted_at, id) keyset.
/// </summary>
public interface IHourlyObservationQueueReadStore
{
    Task<HourlyObservationQueueStorePage> ReadPageAsync(
        HourlyObservationActorContext actor,
        HourlyObservationQueueQuery normalizedQuery,
        CancellationToken cancellationToken);
}

/// <summary>
/// Authenticated, station-scoped read boundary for the station review queue.
/// The client can select only a station already present in its server-resolved
/// active assignment snapshot; the store independently checks live permissions.
/// </summary>
public sealed class HourlyObservationQueueQueryService(
    IHourlyObservationActorContextProvider actorContextProvider,
    IHourlyObservationQueueReadStore store,
    TimeProvider timeProvider)
{
    private const int MaximumPageSize = 100;
    private const int MaximumCursorLength = 2048;

    public async Task<HourlyObservationQueueReadResult> ReadAsync(
        HourlyObservationQueueQuery? query,
        CancellationToken cancellationToken = default)
    {
        if (query is null ||
            query.PageSize is < 1 or > MaximumPageSize ||
            query.Cursor?.Length > MaximumCursorLength ||
            query.StationId?.Any(char.IsControl) == true)
            return InvalidQuery();

        var stationId = query.StationId?.Trim();
        if (query.StationId is not null &&
            (string.IsNullOrWhiteSpace(stationId) ||
             !Guid.TryParseExact(stationId, "D", out var parsedStationId) ||
             !string.Equals(parsedStationId.ToString("D"), stationId, StringComparison.OrdinalIgnoreCase)))
            return InvalidQuery();

        var cursor = string.IsNullOrWhiteSpace(query.Cursor) ? null : query.Cursor;
        if (cursor is not null && cursor.Any(char.IsControl))
            return InvalidQuery();

        var actor = await actorContextProvider.GetCurrentActorAsync(cancellationToken);
        if (actor is null || string.IsNullOrWhiteSpace(actor.UserId))
            return new(HourlyObservationQueueReadStatus.Unauthenticated);

        if (!actor.IsActive ||
            actor.Permissions is null ||
            !actor.Permissions.Contains(HourlyObservationApplicationService.ReviewPermission) ||
            !Guid.TryParseExact(actor.UserId, "D", out var actorId) ||
            !string.Equals(actorId.ToString("D"), actor.UserId, StringComparison.OrdinalIgnoreCase) ||
            actor.StationGrants is null ||
            actor.StationGrants.Any(grant => grant is null ||
                !Guid.TryParseExact(grant.StationId, "D", out _) ||
                string.IsNullOrWhiteSpace(grant.StationId) ||
                grant.ValidFrom.Offset != TimeSpan.Zero ||
                (grant.ValidTo is not null &&
                 (grant.ValidTo.Value.Offset != TimeSpan.Zero || grant.ValidTo.Value <= grant.ValidFrom)) ||
                (grant.RevokedAt is not null && grant.RevokedAt.Value.Offset != TimeSpan.Zero)))
            return new(HourlyObservationQueueReadStatus.Unauthorized);

        var now = timeProvider.GetUtcNow();
        var effectiveStations = actor.StationGrants
            .Where(grant => grant.ValidFrom <= now &&
                (grant.ValidTo is null || now < grant.ValidTo.Value) &&
                (grant.RevokedAt is null || now < grant.RevokedAt.Value))
            .Select(grant => Guid.Parse(grant.StationId).ToString("D"))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        if (effectiveStations.Count == 0 ||
            (stationId is not null && !effectiveStations.Contains(stationId)))
            return new(HourlyObservationQueueReadStatus.Unauthorized);

        var normalized = new HourlyObservationQueueQuery(
            stationId is null ? null : Guid.Parse(stationId).ToString("D"),
            query.PageSize,
            cursor);

        HourlyObservationQueueStorePage page;
        try
        {
            page = await store.ReadPageAsync(actor, normalized, cancellationToken);
        }
        catch (HourlyObservationQueueInvalidCursorException)
        {
            return InvalidQuery();
        }

        if (!IsValidPage(page, normalized, effectiveStations))
            return new(HourlyObservationQueueReadStatus.InvalidStoreResponse);

        return new(
            HourlyObservationQueueReadStatus.Succeeded,
            new(Array.AsReadOnly(page.Items.ToArray()), page.HasMore, page.NextCursor));
    }

    private static bool IsValidPage(
        HourlyObservationQueueStorePage? page,
        HourlyObservationQueueQuery query,
        IReadOnlySet<string> effectiveStations)
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

        var ids = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        HourlyObservationQueueItem? previous = null;
        foreach (var item in page.Items)
        {
            if (item is null ||
                !IsCanonicalGuid(item.ObservationId) ||
                !IsCanonicalGuid(item.StationId) ||
                !IsCanonicalGuid(item.SubmittedBy) ||
                !effectiveStations.Contains(item.StationId) ||
                (query.StationId is not null &&
                 !string.Equals(item.StationId, query.StationId, StringComparison.OrdinalIgnoreCase)) ||
                item.ObservationDate == default ||
                item.UtcHour is < 0 or > 23 ||
                item.SubmittedAtUtc.Offset != TimeSpan.Zero ||
                !ids.Add(item.ObservationId))
                return false;

            if (previous is not null &&
                (previous.SubmittedAtUtc < item.SubmittedAtUtc ||
                 (previous.SubmittedAtUtc == item.SubmittedAtUtc &&
                  string.CompareOrdinal(previous.ObservationId, item.ObservationId) <= 0)))
                return false;

            previous = item;
        }

        return true;
    }

    private static bool IsCanonicalGuid(string value)
        => Guid.TryParseExact(value, "D", out var parsed) &&
           string.Equals(parsed.ToString("D"), value, StringComparison.OrdinalIgnoreCase);

    private static HourlyObservationQueueReadResult InvalidQuery()
        => new(HourlyObservationQueueReadStatus.InvalidQuery);
}
