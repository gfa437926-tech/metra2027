using System.Security.Cryptography;
using System.Text.Json;
using Metra.Api.Domain.Identity;
using Npgsql;
using NpgsqlTypes;
using Microsoft.AspNetCore.DataProtection;

namespace Metra.Api.Features.Identity;

/// <summary>
/// PostgreSQL adapter for registration decisions and the redacted approval queue.
/// Every decision is committed by the database's single atomic, re-authorizing RPC.
/// </summary>
public sealed class NpgsqlRegistrationApprovalStore(
    NpgsqlDataSource dataSource,
    IDataProtectionProvider protectionProvider,
    TimeProvider timeProvider) : IRegistrationApprovalStore, IRegistrationApprovalQueueReadStore
{
    private readonly IDataProtector _cursorProtector =
        protectionProvider.CreateProtector("METRA.RegistrationApprovalQueue.Cursor.v1");

    public async Task<RegistrationApprovalRequestContext?> FindRequestAsync(
        string requestId,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(requestId, out var id))
            return null;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(
            """
            select r.id::text, r.user_id::text, r.requested_station_id::text, r.status,
              (select e.actor_user_id::text from public.registration_audit_events e
               where e.request_id=r.id and e.event_type='station_approved'
               order by e.occurred_at,e.id limit 1)
            from public.registration_requests r where r.id=@id
            """, connection);
        command.Parameters.Add("id", NpgsqlDbType.Uuid).Value = id;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
            return null;

        if (!TryParseStatus(reader.GetString(3), out var status))
            throw new InvalidOperationException("Registration request has an unknown persisted status.");

        return new RegistrationApprovalRequestContext(
            reader.GetString(0),
            reader.GetString(1),
            reader.GetString(2),
            status,
            reader.IsDBNull(4) ? null : reader.GetString(4));
    }

    public async Task<RegistrationApprovalCommitResult> TryCommitDecisionAsync(
        string requestId,
        RegistrationApprovalStatus expectedStatus,
        RegistrationApprovalTransition transition,
        string actorUserId,
        string? note,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(requestId, out var requestGuid) ||
            !Guid.TryParse(actorUserId, out var actorGuid) ||
            transition.From != expectedStatus)
            return RegistrationApprovalCommitResult.Conflict;

        try
        {
            await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
            await using var command = new NpgsqlCommand(
                """
                select result_status, resulting_status
                from private.decide_metra_registration(
                  @request_id,@actor_id,@decision,@note,@occurred_at)
                """, connection);
            command.Parameters.Add("request_id", NpgsqlDbType.Uuid).Value = requestGuid;
            command.Parameters.Add("actor_id", NpgsqlDbType.Uuid).Value = actorGuid;
            command.Parameters.Add("decision", NpgsqlDbType.Text).Value =
                transition.Decision == RegistrationApprovalDecision.Approve ? "approve" : "reject";
            command.Parameters.Add("note", NpgsqlDbType.Text).Value = (object?)note ?? DBNull.Value;
            command.Parameters.Add("occurred_at", NpgsqlDbType.TimestampTz).Value = timeProvider.GetUtcNow();

            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
                throw new InvalidOperationException("Registration approval persistence returned no outcome.");

            return reader.GetString(0) switch
            {
                "committed" => RegistrationApprovalCommitResult.Committed,
                "not_found" => RegistrationApprovalCommitResult.NotFound,
                "conflict" => RegistrationApprovalCommitResult.Conflict,
                "unauthorized" => RegistrationApprovalCommitResult.Conflict,
                _ => throw new InvalidOperationException("Registration approval persistence returned an unknown outcome.")
            };
        }
        catch (PostgresException exception) when (
            exception.SqlState is PostgresErrorCodes.UniqueViolation or "23P01" or PostgresErrorCodes.CheckViolation)
        {
            return RegistrationApprovalCommitResult.Conflict;
        }
    }

    public async Task<RegistrationApprovalQueueStorePage> ReadPageAsync(
        RegistrationApprovalActorContext actor,
        RegistrationApprovalQueueQuery query,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(actor.UserId, out var actorId))
            throw new InvalidOperationException("Approval actor ID is invalid.");

        var stationIds = actor.StationManagerStationIds
            .Select(value => Guid.TryParse(value, out var id) ? id : Guid.Empty)
            .Where(value => value != Guid.Empty)
            .Distinct()
            .ToArray();

        QueueCursor? cursor = null;
        if (query.Cursor is not null)
        {
            try
            {
                cursor = JsonSerializer.Deserialize<QueueCursor>(
                    _cursorProtector.Unprotect(query.Cursor));
            }
            catch (Exception exception) when (
                exception is CryptographicException or JsonException or FormatException)
            {
                throw new InvalidOperationException("Approval queue cursor is invalid.");
            }

            if (cursor is null ||
                cursor.ActorId != actorId ||
                cursor.Status != query.Status ||
                cursor.StationId != query.StationId ||
                cursor.PageSize != query.PageSize ||
                !Guid.TryParse(cursor.RequestId, out _) ||
                cursor.SubmittedAtUtc.Offset != TimeSpan.Zero)
                throw new InvalidOperationException("Approval queue cursor does not match this query.");
        }

        Guid? requestedStation = null;
        if (query.StationId is not null)
        {
            if (!Guid.TryParse(query.StationId, out var stationId))
                return new(Array.Empty<RegistrationApprovalQueueItem>(), false, null);
            requestedStation = stationId;
        }

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(
            """
            select r.id::text, r.user_id::text, r.requested_station_id::text,
                   r.requested_role_code, r.status, r.submitted_at
            from public.registration_requests r
            where (
              (r.status='pending_system_approval' and @can_system)
              or
              (r.status='pending_station_approval' and @can_station
               and r.requested_station_id = any(@station_ids))
            )
            and (@requested_status is null or r.status=@requested_status)
            and (@requested_station is null or r.requested_station_id=@requested_station)
            and (@cursor_at is null or (r.submitted_at,r.id) < (@cursor_at,@cursor_id))
            order by r.submitted_at desc,r.id desc
            limit @limit
            """, connection);
        command.Parameters.Add("can_system", NpgsqlDbType.Boolean).Value = actor.CanApproveSystemRegistrations;
        command.Parameters.Add("can_station", NpgsqlDbType.Boolean).Value = actor.CanApproveStationRegistrations;
        command.Parameters.Add("station_ids", NpgsqlDbType.Array | NpgsqlDbType.Uuid).Value = stationIds;
        command.Parameters.Add("requested_status", NpgsqlDbType.Text).Value =
            query.Status is { } status ? ToDatabaseStatus(status) : DBNull.Value;
        command.Parameters.Add("requested_station", NpgsqlDbType.Uuid).Value =
            (object?)requestedStation ?? DBNull.Value;
        command.Parameters.Add("cursor_at", NpgsqlDbType.TimestampTz).Value =
            (object?)cursor?.SubmittedAtUtc ?? DBNull.Value;
        command.Parameters.Add("cursor_id", NpgsqlDbType.Uuid).Value =
            cursor is null ? DBNull.Value : Guid.Parse(cursor.RequestId);
        command.Parameters.Add("limit", NpgsqlDbType.Integer).Value = query.PageSize + 1;

        var items = new List<RegistrationApprovalQueueItem>();
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                if (!TryParseStatus(reader.GetString(4), out var status))
                    throw new InvalidOperationException("Approval queue contains an unknown status.");
                items.Add(new(
                    reader.GetString(0), reader.GetString(1), reader.GetString(2),
                    reader.GetString(3), status, reader.GetFieldValue<DateTimeOffset>(5).ToUniversalTime()));
            }
        }

        var hasMore = items.Count > query.PageSize;
        if (hasMore)
            items.RemoveAt(items.Count - 1);

        string? nextCursor = null;
        if (hasMore && items.Count > 0)
        {
            var last = items[^1];
            nextCursor = _cursorProtector.Protect(JsonSerializer.Serialize(
                new QueueCursor(actorId, query.Status, query.StationId, query.PageSize,
                    last.SubmittedAtUtc, last.RequestId)));
        }

        return new(Array.AsReadOnly(items.ToArray()), hasMore, nextCursor);
    }

    private static string ToDatabaseStatus(RegistrationApprovalStatus status) => status switch
    {
        RegistrationApprovalStatus.PendingStationApproval => "pending_station_approval",
        RegistrationApprovalStatus.PendingSystemApproval => "pending_system_approval",
        RegistrationApprovalStatus.Active => "active",
        RegistrationApprovalStatus.Rejected => "rejected",
        _ => throw new ArgumentOutOfRangeException(nameof(status))
    };

    private static bool TryParseStatus(string value, out RegistrationApprovalStatus status)
    {
        status = value switch
        {
            "pending_station_approval" => RegistrationApprovalStatus.PendingStationApproval,
            "pending_system_approval" => RegistrationApprovalStatus.PendingSystemApproval,
            "active" => RegistrationApprovalStatus.Active,
            "rejected" => RegistrationApprovalStatus.Rejected,
            _ => (RegistrationApprovalStatus)(-1)
        };
        return Enum.IsDefined(status);
    }

    private sealed record QueueCursor(
        Guid ActorId,
        RegistrationApprovalStatus? Status,
        string? StationId,
        int PageSize,
        DateTimeOffset SubmittedAtUtc,
        string RequestId);
}
