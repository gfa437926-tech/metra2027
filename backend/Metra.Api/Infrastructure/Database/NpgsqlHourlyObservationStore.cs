using Metra.Api.Features.Observations;
using Npgsql;
using NpgsqlTypes;

namespace Metra.Api.Infrastructure.Database;

/// <summary>
/// PostgreSQL persistence adapter for hourly observations. The matching schema
/// is documented in docs/architecture/HOURLY-OBSERVATION-PERSISTENCE-PROPOSAL.md
/// and must be approved/applied before this adapter is registered in production.
/// Each report mutation and its audit event share one database transaction.
/// </summary>
public sealed class NpgsqlHourlyObservationStore(NpgsqlDataSource dataSource)
    : IHourlyObservationStore
{
    public async Task<PersistedHourlyObservation> CreateAsync(
        PersistHourlyObservationCommand command,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);
        if (!Guid.TryParse(command.StationId, out var stationId) ||
            !Guid.TryParse(command.SubmittedBy, out var submittedBy))
            throw new InvalidOperationException("Hourly observation actor or station identifier is invalid.");

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        const string authorizationSql = """
            select exists (
              select 1
              from public.metra_account_states s
              join public.permission_grants p on p.user_id=s.user_id
              join public.station_assignments a on a.user_id=s.user_id
              where s.user_id=@actor_id and s.account_state='active'
                and p.permission_code=@permission and p.approval_status='approved'
                and p.valid_from <= now() and (p.valid_to is null or p.valid_to > now())
                and (p.revoked_at is null or p.revoked_at > now())
                and a.station_id=@station_id and a.approval_status='approved'
                and a.valid_from <= now() and (a.valid_to is null or a.valid_to > now())
                and (a.revoked_at is null or a.revoked_at > now())
              for share of s, p, a
            )
            """;
        await using (var authorization = new NpgsqlCommand(authorizationSql, connection, transaction))
        {
            authorization.Parameters.Add("actor_id", NpgsqlDbType.Uuid).Value = submittedBy;
            authorization.Parameters.Add("permission", NpgsqlDbType.Text).Value =
                HourlyObservationApplicationService.SubmitPermission;
            authorization.Parameters.Add("station_id", NpgsqlDbType.Uuid).Value = stationId;
            if (await authorization.ExecuteScalarAsync(cancellationToken) is not true)
            {
                await transaction.RollbackAsync(cancellationToken);
                throw new UnauthorizedAccessException("Hourly observation submission authorization is no longer valid.");
            }
        }

        var observationId = Guid.NewGuid();
        const string insertSql = """
            insert into public.hourly_observations
              (id, station_id, submitted_by, observation_date, utc_hour, observation_values, status, submitted_at)
            values
              (@id, @station_id, @submitted_by, @observation_date, @utc_hour,
               @values::jsonb, 'pending_review', now())
            returning submitted_at
            """;
        DateTimeOffset submittedAt;
        await using (var insert = new NpgsqlCommand(insertSql, connection, transaction))
        {
            insert.Parameters.Add("id", NpgsqlDbType.Uuid).Value = observationId;
            insert.Parameters.Add("station_id", NpgsqlDbType.Uuid).Value = stationId;
            insert.Parameters.Add("submitted_by", NpgsqlDbType.Uuid).Value = submittedBy;
            insert.Parameters.Add("observation_date", NpgsqlDbType.Date).Value = command.ObservationDate;
            insert.Parameters.Add("utc_hour", NpgsqlDbType.Smallint).Value = command.UtcHour;
            insert.Parameters.Add("values", NpgsqlDbType.Jsonb).Value =
                System.Text.Json.JsonSerializer.Serialize(command.Values);
            var submittedAtValue = await insert.ExecuteScalarAsync(cancellationToken)
                ?? throw new InvalidOperationException("Hourly observation insert returned no timestamp.");
            submittedAt = submittedAtValue switch
            {
                DateTimeOffset timestamp => timestamp.ToUniversalTime(),
                DateTime timestamp => new DateTimeOffset(
                    DateTime.SpecifyKind(timestamp, DateTimeKind.Utc)),
                _ => throw new InvalidOperationException("Hourly observation insert returned an invalid timestamp.")
            };
        }

        const string auditSql = """
            insert into public.hourly_observation_audit_events
              (observation_id, station_id, actor_user_id, event_type, from_status, to_status, note, occurred_at)
            values (@observation_id, @station_id, @actor_user_id,
                    'submitted', null, 'pending_review', null, now())
            """;
        await using (var audit = new NpgsqlCommand(auditSql, connection, transaction))
        {
            audit.Parameters.Add("observation_id", NpgsqlDbType.Uuid).Value = observationId;
            audit.Parameters.Add("station_id", NpgsqlDbType.Uuid).Value = stationId;
            audit.Parameters.Add("actor_user_id", NpgsqlDbType.Uuid).Value = submittedBy;
            await audit.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        return new PersistedHourlyObservation(
            observationId.ToString("D"), stationId.ToString("D"), submittedBy.ToString("D"),
            command.ObservationDate, command.UtcHour, HourlyObservationStatus.PendingReview, submittedAt);
    }

    public async Task<HourlyObservationReviewTarget?> FindReviewTargetAsync(
        string observationId,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(observationId, out var id))
            return null;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(
            """
            select id::text, station_id::text, submitted_by::text, status
            from public.hourly_observations
            where id=@id
            """, connection);
        command.Parameters.Add("id", NpgsqlDbType.Uuid).Value = id;
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
            return null;

        return new HourlyObservationReviewTarget(
            reader.GetString(0), reader.GetString(1), reader.GetString(2),
            ParseStatus(reader.GetString(3)));
    }

    public async Task<HourlyObservationStoreResult> CommitReviewAsync(
        CommitHourlyObservationReviewCommand command,
        string requiredPermission,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(command);
        if (!Guid.TryParse(command.ObservationId, out var observationId) ||
            !Guid.TryParse(command.ReviewedBy, out var reviewerId) ||
            requiredPermission != HourlyObservationApplicationService.ReviewPermission)
            return HourlyObservationStoreResult.Conflict;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        string? stationId = null;
        string? submitterId = null;
        string? currentStatus = null;
        await using (var load = new NpgsqlCommand(
            """
            select station_id::text, submitted_by::text, status
            from public.hourly_observations
            where id=@id
            for update
            """, connection, transaction))
        {
            load.Parameters.Add("id", NpgsqlDbType.Uuid).Value = observationId;
            await using var reader = await load.ExecuteReaderAsync(cancellationToken);
            if (await reader.ReadAsync(cancellationToken))
            {
                stationId = reader.GetString(0);
                submitterId = reader.GetString(1);
                currentStatus = reader.GetString(2);
            }
        }

        if (stationId is null)
        {
            await transaction.RollbackAsync(cancellationToken);
            return HourlyObservationStoreResult.NotFound;
        }

        if (!Guid.TryParse(stationId, out var stationGuid) ||
            !Guid.TryParse(submitterId, out var submitterGuid) ||
            submitterGuid == reviewerId ||
            currentStatus != ToDatabaseStatus(command.ExpectedStatus) ||
            command.NewStatus is not (HourlyObservationStatus.Approved or HourlyObservationStatus.Rejected))
        {
            await transaction.RollbackAsync(cancellationToken);
            return HourlyObservationStoreResult.Conflict;
        }

        // Authorization is rechecked while the observation row is locked.
        // The runtime role is intentionally restricted to the approved
        // METRA identity tables; no client-provided station/permission is trusted.
        const string authorizationSql = """
            select exists (
              select 1
              from public.metra_account_states s
              join public.permission_grants p on p.user_id=s.user_id
              join public.station_assignments a on a.user_id=s.user_id
              where s.user_id=@reviewer_id and s.account_state='active'
                and p.permission_code=@permission and p.approval_status='approved'
                and p.valid_from <= now() and (p.valid_to is null or p.valid_to > now())
                and (p.revoked_at is null or p.revoked_at > now())
                and a.station_id=@station_id and a.approval_status='approved'
                and a.valid_from <= now() and (a.valid_to is null or a.valid_to > now())
                and (a.revoked_at is null or a.revoked_at > now())
              for share of s, p, a
            )
            """;
        await using (var authorization = new NpgsqlCommand(authorizationSql, connection, transaction))
        {
            authorization.Parameters.Add("reviewer_id", NpgsqlDbType.Uuid).Value = reviewerId;
            authorization.Parameters.Add("permission", NpgsqlDbType.Text).Value = requiredPermission;
            authorization.Parameters.Add("station_id", NpgsqlDbType.Uuid).Value = stationGuid;
            if (await authorization.ExecuteScalarAsync(cancellationToken) is not true)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HourlyObservationStoreResult.Conflict;
            }
        }

        const string updateSql = """
            update public.hourly_observations
            set status=@new_status, reviewed_by=@reviewed_by, reviewed_at=now(), review_note=@note
            where id=@id and status=@expected_status
            """;
        await using (var update = new NpgsqlCommand(updateSql, connection, transaction))
        {
            update.Parameters.Add("new_status", NpgsqlDbType.Text).Value = ToDatabaseStatus(command.NewStatus);
            update.Parameters.Add("reviewed_by", NpgsqlDbType.Uuid).Value = reviewerId;
            update.Parameters.Add("note", NpgsqlDbType.Text).Value = (object?)command.Note ?? DBNull.Value;
            update.Parameters.Add("id", NpgsqlDbType.Uuid).Value = observationId;
            update.Parameters.Add("expected_status", NpgsqlDbType.Text).Value = ToDatabaseStatus(command.ExpectedStatus);
            if (await update.ExecuteNonQueryAsync(cancellationToken) != 1)
            {
                await transaction.RollbackAsync(cancellationToken);
                return HourlyObservationStoreResult.Conflict;
            }
        }

        const string auditSql = """
            insert into public.hourly_observation_audit_events
              (observation_id, station_id, actor_user_id, event_type, from_status, to_status, note, occurred_at)
            values (@observation_id, @station_id, @actor_user_id, @event_type,
                    @from_status, @to_status, @note, now())
            """;
        await using (var audit = new NpgsqlCommand(auditSql, connection, transaction))
        {
            audit.Parameters.Add("observation_id", NpgsqlDbType.Uuid).Value = observationId;
            audit.Parameters.Add("station_id", NpgsqlDbType.Uuid).Value = stationGuid;
            audit.Parameters.Add("actor_user_id", NpgsqlDbType.Uuid).Value = reviewerId;
            audit.Parameters.Add("event_type", NpgsqlDbType.Text).Value =
                command.NewStatus == HourlyObservationStatus.Approved ? "approved" : "rejected";
            audit.Parameters.Add("from_status", NpgsqlDbType.Text).Value = ToDatabaseStatus(command.ExpectedStatus);
            audit.Parameters.Add("to_status", NpgsqlDbType.Text).Value = ToDatabaseStatus(command.NewStatus);
            audit.Parameters.Add("note", NpgsqlDbType.Text).Value = (object?)command.Note ?? DBNull.Value;
            await audit.ExecuteNonQueryAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        return HourlyObservationStoreResult.Committed;
    }

    private static string ToDatabaseStatus(HourlyObservationStatus status) => status switch
    {
        HourlyObservationStatus.PendingReview => "pending_review",
        HourlyObservationStatus.Approved => "approved",
        HourlyObservationStatus.Rejected => "rejected",
        _ => throw new ArgumentOutOfRangeException(nameof(status))
    };

    private static HourlyObservationStatus ParseStatus(string status) => status switch
    {
        "pending_review" => HourlyObservationStatus.PendingReview,
        "approved" => HourlyObservationStatus.Approved,
        "rejected" => HourlyObservationStatus.Rejected,
        _ => throw new InvalidOperationException("Hourly observation has an unknown persisted status.")
    };
}
