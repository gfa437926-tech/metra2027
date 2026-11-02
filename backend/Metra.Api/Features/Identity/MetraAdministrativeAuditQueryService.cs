using Metra.Api.Domain.Identity;

namespace Metra.Api.Features.Identity;

/// <summary>
/// Server-side audit search filters. Cursor contents are opaque to the API and
/// are interpreted only by the trusted persistence adapter.
/// </summary>
public sealed record MetraAdministrativeAuditQuery(
    string? TargetAccountId,
    string? ActorUserId,
    string? ActionCode,
    string? ResourceType,
    DateTimeOffset? OccurredFromUtc,
    DateTimeOffset? OccurredBeforeUtc,
    int PageSize,
    string? Cursor);

/// <summary>
/// Deliberately redacted default list projection. Free-text reason and
/// before/after values are excluded from ordinary list responses.
/// </summary>
public sealed record MetraAdministrativeAuditListItem(
    string EventId,
    string TargetAccountId,
    string ActorUserId,
    string ActionCode,
    string ResourceType,
    string ResourceId,
    DateTimeOffset OccurredAtUtc,
    string CorrelationId,
    long AggregateVersion);

public sealed record MetraAdministrativeAuditPage(
    IReadOnlyList<MetraAdministrativeAuditListItem> Items,
    string? NextCursor,
    bool HasMore);

/// <summary>
/// Internal store page carries complete domain events so the application
/// service can validate them before producing the redacted API projection.
/// </summary>
public sealed record MetraAdministrativeAuditStorePage(
    IReadOnlyList<MetraAdministrativeAuditEvent> Events,
    string? NextCursor,
    bool HasMore);

public enum MetraAdministrativeAuditReadResult
{
    Success = 0,
    ActorNotAuthorized = 1,
    CursorInvalid = 2
}

/// <summary>
/// The adapter must enforce audit-read permission and any approved station/data
/// scope on every request. Use keyset pagination ordered by (OccurredAtUtc,
/// EventId), return at most PageSize records, and never mutate audit rows.
/// Cursors must be integrity-protected and bound to the actor + normalized
/// filter set; reject tampering, cross-actor reuse and expired cursors.
/// </summary>
public interface IMetraAdministrativeAuditReadStore
{
    Task<(MetraAdministrativeAuditReadResult Result, MetraAdministrativeAuditStorePage? Page)>
        ReadAsync(string actorUserId, MetraAdministrativeAuditQuery query,
            CancellationToken cancellationToken);
}

public sealed record MetraAdministrativeAuditQueryResult(
    bool Succeeded,
    string Code,
    MetraAdministrativeAuditPage? Page = null);

/// <summary>
/// Validates bounded audit filters and delegates authorization + scoped reads
/// to the trusted store. The API never interprets or constructs cursor values.
/// </summary>
public sealed class MetraAdministrativeAuditQueryService(
    IAccountLifecycleActorContextProvider actorContextProvider,
    IMetraAdministrativeAuditReadStore store)
{
    private const int MaximumPageSize = 100;
    private const int MaximumCursorLength = 2048;

    public async Task<MetraAdministrativeAuditQueryResult> ExecuteAsync(
        MetraAdministrativeAuditQuery query,
        CancellationToken cancellationToken = default)
    {
        if (query is null)
            return Failure("audit_query_required");

        if (query.PageSize is < 1 or > MaximumPageSize)
            return Failure("audit_page_size_invalid");

        if (!IsOptionalIdentifier(query.TargetAccountId) ||
            !IsOptionalIdentifier(query.ActorUserId))
            return Failure("audit_filter_identifier_invalid");

        if (!IsOptionalCode(query.ActionCode) || !IsOptionalCode(query.ResourceType))
            return Failure("audit_filter_code_invalid");

        if ((query.OccurredFromUtc is { Offset: var fromOffset } && fromOffset != TimeSpan.Zero) ||
            (query.OccurredBeforeUtc is { Offset: var beforeOffset } && beforeOffset != TimeSpan.Zero))
            return Failure("audit_filter_timestamp_must_be_utc");

        if (query.OccurredFromUtc is not null &&
            query.OccurredBeforeUtc is not null &&
            query.OccurredFromUtc >= query.OccurredBeforeUtc)
            return Failure("audit_filter_time_range_invalid");

        if (query.Cursor is { } cursor &&
            (string.IsNullOrWhiteSpace(cursor) || cursor.Length > MaximumCursorLength ||
             cursor.Any(char.IsControl)))
            return Failure("audit_cursor_invalid");

        var actorId = await actorContextProvider.GetCurrentActorUserIdAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(actorId))
            return Failure("unauthenticated");
        if (actorId != actorId.Trim() || actorId.Length > 128 || actorId.Any(char.IsControl))
            return Failure("actor_context_invalid");

        var read = await store.ReadAsync(actorId, query, cancellationToken);
        if (read.Result == MetraAdministrativeAuditReadResult.ActorNotAuthorized)
            return Failure("actor_not_authorized");
        if (read.Result == MetraAdministrativeAuditReadResult.CursorInvalid)
            return Failure("audit_cursor_invalid");
        if (read.Result != MetraAdministrativeAuditReadResult.Success)
            return Failure("audit_query_failed");

        if (!TryMapPage(read.Page, query, out var safePage))
            return Failure("audit_store_response_invalid");

        return new(true, "audit_query_succeeded", safePage);
    }

    private static bool TryMapPage(
        MetraAdministrativeAuditStorePage? page,
        MetraAdministrativeAuditQuery query,
        out MetraAdministrativeAuditPage? safePage)
    {
        safePage = null;
        if (page?.Events is null || page.Events.Count > query.PageSize)
            return false;
        if (page.HasMore &&
            (page.Events.Count == 0 ||
             string.IsNullOrWhiteSpace(page.NextCursor) ||
             page.NextCursor.Length > MaximumCursorLength ||
             page.NextCursor.Any(char.IsControl) ||
             string.Equals(query.Cursor, page.NextCursor, StringComparison.Ordinal)))
            return false;
        if (!page.HasMore && page.NextCursor is not null)
            return false;

        var seenIds = new HashSet<string>(StringComparer.Ordinal);
        var projected = new List<MetraAdministrativeAuditListItem>(page.Events.Count);
        MetraAdministrativeAuditEvent? previous = null;

        foreach (var auditEvent in page.Events)
        {
            if (!MetraAdministrativeAuditEventPolicy.Validate(auditEvent).IsValid ||
                !seenIds.Add(auditEvent.EventId))
                return false;

            if (previous is not null &&
                (previous.OccurredAtUtc < auditEvent.OccurredAtUtc ||
                 previous.OccurredAtUtc == auditEvent.OccurredAtUtc &&
                 string.CompareOrdinal(previous.EventId, auditEvent.EventId) < 0))
                return false;

            projected.Add(new(
                auditEvent.EventId,
                auditEvent.TargetAccountId,
                auditEvent.ActorUserId,
                auditEvent.ActionCode,
                auditEvent.ResourceType,
                auditEvent.ResourceId,
                auditEvent.OccurredAtUtc,
                auditEvent.CorrelationId,
                auditEvent.AggregateVersion));
            previous = auditEvent;
        }

        safePage = new(projected.AsReadOnly(), page.NextCursor, page.HasMore);
        return true;
    }

    private static bool IsOptionalIdentifier(string? value)
        => value is null || (!string.IsNullOrWhiteSpace(value) &&
            value.Length <= 128 && value == value.Trim() &&
            value.All(character => character is >= 'a' and <= 'z' or
                >= 'A' and <= 'Z' or >= '0' and <= '9' or '-' or '_' or ':' or '.'));

    private static bool IsOptionalCode(string? value)
    {
        if (value is null)
            return true;
        if (value.Length is 0 or > 128)
            return false;

        var hasCharacter = false;
        foreach (var character in value)
        {
            if (character is >= 'a' and <= 'z' or >= '0' and <= '9')
            {
                hasCharacter = true;
                continue;
            }

            if (character is '.' or '_' or '-')
            {
                if (!hasCharacter)
                    return false;
                hasCharacter = false;
                continue;
            }

            return false;
        }

        return hasCharacter;
    }

    private static MetraAdministrativeAuditQueryResult Failure(string code)
        => new(false, code);
}
