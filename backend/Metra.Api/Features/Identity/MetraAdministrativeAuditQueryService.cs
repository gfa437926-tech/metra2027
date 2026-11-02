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

public sealed record MetraAdministrativeAuditPage(
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
/// </summary>
public interface IMetraAdministrativeAuditReadStore
{
    Task<(MetraAdministrativeAuditReadResult Result, MetraAdministrativeAuditPage? Page)>
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

        if (query.OccurredFromUtc is { Offset: var fromOffset } && fromOffset != TimeSpan.Zero ||
            query.OccurredBeforeUtc is { Offset: var beforeOffset } && beforeOffset != TimeSpan.Zero)
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
        return read.Result switch
        {
            MetraAdministrativeAuditReadResult.Success when read.Page is not null =>
                new(true, "audit_query_succeeded", read.Page),
            MetraAdministrativeAuditReadResult.Success => Failure("audit_store_response_invalid"),
            MetraAdministrativeAuditReadResult.ActorNotAuthorized => Failure("actor_not_authorized"),
            MetraAdministrativeAuditReadResult.CursorInvalid => Failure("audit_cursor_invalid"),
            _ => Failure("audit_query_failed")
        };
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
