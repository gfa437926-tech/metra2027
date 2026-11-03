using Metra.Api.Domain.Identity;

namespace Metra.Api.Features.Identity;

/// <summary>
/// Bounded filters for the registration approval work queue. The cursor is opaque
/// to the API and is interpreted only by the trusted read store.
/// </summary>
public sealed record RegistrationApprovalQueueQuery(
    RegistrationApprovalStatus? Status = null,
    string? StationId = null,
    int PageSize = 50,
    string? Cursor = null);

/// <summary>
/// Redacted queue projection. Applicant identity is an internal METRA account ID;
/// the queue does not expose Auth provider subjects, contact details or free text.
/// </summary>
public sealed record RegistrationApprovalQueueItem(
    string RequestId,
    string ApplicantAccountId,
    string RequestedStationId,
    string RequestedRoleCode,
    RegistrationApprovalStatus Status,
    DateTimeOffset SubmittedAtUtc);

public sealed record RegistrationApprovalQueueStorePage(
    IReadOnlyList<RegistrationApprovalQueueItem> Items,
    bool HasMore,
    string? NextCursor);

public sealed record RegistrationApprovalQueuePage(
    IReadOnlyList<RegistrationApprovalQueueItem> Items,
    bool HasMore,
    string? NextCursor);

public enum RegistrationApprovalQueueReadStatus
{
    Succeeded = 0,
    Unauthenticated = 1,
    Unauthorized = 2,
    InvalidQuery = 3,
    InvalidStoreResponse = 4
}

public sealed record RegistrationApprovalQueueReadResult(
    RegistrationApprovalQueueReadStatus Status,
    RegistrationApprovalQueuePage? Page = null)
{
    public bool Succeeded => Status == RegistrationApprovalQueueReadStatus.Succeeded;
}

public sealed class RegistrationApprovalQueueInvalidCursorException : Exception;

/// <summary>
/// Store contract: enforce the exact queue-read permission and approved station
/// scope for every call. A station approver sees only assigned stations; a system
/// approver sees only the system-stage queue unless a separately approved policy
/// grants broader visibility. Verify cursor integrity and bind it to actor and
/// normalized filters. Use keyset order (SubmittedAtUtc DESC, RequestId DESC).
/// </summary>
public interface IRegistrationApprovalQueueReadStore
{
    Task<RegistrationApprovalQueueStorePage> ReadPageAsync(
        RegistrationApprovalActorContext actor,
        RegistrationApprovalQueueQuery normalizedQuery,
        CancellationToken cancellationToken);
}

/// <summary>
/// Read-only application boundary for the approval work queue. Authorization and
/// station visibility remain enforced by the store against authoritative facts.
/// </summary>
public sealed class RegistrationApprovalQueueQueryService(
    IRegistrationApprovalActorContextProvider actorContextProvider,
    IRegistrationApprovalQueueReadStore store)
{
    private const int MaximumPageSize = 100;
    private const int MaximumCursorLength = 2048;
    private const int MaximumStationIdLength = 128;

    public async Task<RegistrationApprovalQueueReadResult> ReadAsync(
        RegistrationApprovalQueueQuery? query,
        CancellationToken cancellationToken = default)
    {
        if (query is null ||
            query.PageSize is < 1 or > MaximumPageSize ||
            query.Cursor?.Length > MaximumCursorLength ||
            query.StationId?.Any(char.IsControl) == true)
            return InvalidQuery();

        if (query.Status is { } status &&
            (!Enum.IsDefined(status) || status is not (
                RegistrationApprovalStatus.PendingStationApproval or
                RegistrationApprovalStatus.PendingSystemApproval)))
            return InvalidQuery();

        var stationId = query.StationId?.Trim();
        if (stationId is { Length: > MaximumStationIdLength } ||
            (query.StationId is not null && string.IsNullOrWhiteSpace(stationId)))
            return InvalidQuery();

        var cursor = string.IsNullOrWhiteSpace(query.Cursor) ? null : query.Cursor;
        if (cursor is not null && cursor.Any(char.IsControl))
            return InvalidQuery();

        var actor = await actorContextProvider.GetCurrentActorAsync(cancellationToken);
        if (actor is null || string.IsNullOrWhiteSpace(actor.UserId))
            return new(RegistrationApprovalQueueReadStatus.Unauthenticated);

        if (!actor.IsActive ||
            (!actor.CanApproveStationRegistrations && !actor.CanApproveSystemRegistrations))
            return new(RegistrationApprovalQueueReadStatus.Unauthorized);

        if (actor.UserId != actor.UserId.Trim() ||
            actor.UserId.Length > 128 || actor.UserId.Any(char.IsControl) ||
            actor.StationManagerStationIds is null ||
            actor.StationManagerStationIds.Any(id =>
                string.IsNullOrWhiteSpace(id) || id != id.Trim() ||
                id.Length > MaximumStationIdLength || id.Any(char.IsControl)))
            return new(RegistrationApprovalQueueReadStatus.Unauthorized);

        var normalized = new RegistrationApprovalQueueQuery(
            query.Status,
            stationId,
            query.PageSize,
            cursor);

        RegistrationApprovalQueueStorePage page;
        try
        {
            page = await store.ReadPageAsync(actor, normalized, cancellationToken);
        }
        catch (RegistrationApprovalQueueInvalidCursorException)
        {
            return InvalidQuery();
        }
        if (!IsValidPage(page, normalized))
            return new(RegistrationApprovalQueueReadStatus.InvalidStoreResponse);

        return new(
            RegistrationApprovalQueueReadStatus.Succeeded,
            new(Array.AsReadOnly(page.Items.ToArray()), page.HasMore, page.NextCursor));
    }

    private static bool IsValidPage(
        RegistrationApprovalQueueStorePage? page,
        RegistrationApprovalQueueQuery query)
    {
        if (page?.Items is null || page.Items.Count > query.PageSize ||
            (page.HasMore && page.Items.Count == 0))
            return false;

        if (page.HasMore != !string.IsNullOrWhiteSpace(page.NextCursor))
            return false;

        if (page.NextCursor?.Length > MaximumCursorLength ||
            page.NextCursor?.Any(char.IsControl) == true ||
            (page.NextCursor is not null && string.Equals(page.NextCursor, query.Cursor, StringComparison.Ordinal)))
            return false;

        var ids = new HashSet<string>(StringComparer.Ordinal);
        RegistrationApprovalQueueItem? previous = null;
        foreach (var item in page.Items)
        {
            if (item is null ||
                (query.Status is { } requestedStatus && item.Status != requestedStatus) ||
                (query.StationId is not null && item.RequestedStationId != query.StationId) ||
                !IsIdentifier(item.RequestId) ||
                !IsIdentifier(item.ApplicantAccountId) ||
                !IsIdentifier(item.RequestedStationId) ||
                !IsCanonicalCode(item.RequestedRoleCode) ||
                !Enum.IsDefined(item.Status) ||
                item.SubmittedAtUtc.Offset != TimeSpan.Zero ||
                !ids.Add(item.RequestId))
                return false;

            if (previous is not null &&
                (previous.SubmittedAtUtc < item.SubmittedAtUtc ||
                 (previous.SubmittedAtUtc == item.SubmittedAtUtc &&
                  string.CompareOrdinal(previous.RequestId, item.RequestId) <= 0)))
                return false;

            previous = item;
        }

        return true;
    }

    private static bool IsIdentifier(string value)
        => !string.IsNullOrWhiteSpace(value) &&
           value.Length <= 128 &&
           value == value.Trim() &&
           value.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_' or '.');

    private static bool IsCanonicalCode(string value)
        => !string.IsNullOrWhiteSpace(value) &&
           value.Length <= 128 &&
           value == value.Trim() &&
           value == value.ToLowerInvariant() &&
           value.All(c => char.IsAsciiLetterOrDigit(c) || c is '.' or '_' or '-');

    private static RegistrationApprovalQueueReadResult InvalidQuery()
        => new(RegistrationApprovalQueueReadStatus.InvalidQuery);
}
