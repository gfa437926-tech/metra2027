using System.Data;
using System.Net;
using System.Text.Json;
using Metra.Api.Domain.Support;
using Metra.Api.Features.Support;
using Metra.Api.Security;
using Npgsql;
using NpgsqlTypes;

namespace Metra.Api.Infrastructure.Persistence;

/// <summary>
/// Station-scoped support incident persistence over Npgsql with the same
/// constrained role + transaction-local app.station_id / app.user_id model
/// used by equipment faults.
/// </summary>
public sealed class NpgsqlSupportIncidentService(
    IConfiguration configuration,
    IStationAuthorizationService authorization) : ISupportIncidentService
{
    private readonly string? _connectionString = configuration.GetConnectionString("MetraOps");

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task<SupportIncidentServiceOutcome> SubmitAsync(
        Guid userId,
        Guid stationId,
        SupportIncidentSubmitRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new(false, false, null, null);

        var allowed = await authorization.HasStationPermissionAsync(
            userId, stationId, "support_incident.create", cancellationToken);
        if (!allowed)
            return new(true, false, HttpStatusCode.Forbidden, null);

        var (conn, tx) = await NpgsqlOpsSession.BeginScopedAsync(
            _connectionString!, userId, stationId, cancellationToken);
        await using (conn)
        await using (tx)
        {
            try
            {
                var id = Guid.NewGuid();
                await using var cmd = new NpgsqlCommand(
                    """
                    insert into public.metra_support_incidents (
                      id, station_id, reporter_user_id, kind, category, title, description,
                      affected_asset, severity, status, impacts_operations, occurred_at,
                      created_at, updated_at)
                    values (
                      @id, @station_id, @reporter, @kind, @category, @title, @description,
                      @affected_asset, @severity, 'Submitted', @impacts, @occurred_at,
                      now(), now())
                    returning id, station_id, reporter_user_id, kind, category, title, description,
                              affected_asset, severity, status, impacts_operations, occurred_at,
                              assigned_to, created_at, updated_at;
                    """, conn, tx);
                cmd.Parameters.AddWithValue("id", id);
                cmd.Parameters.AddWithValue("station_id", stationId);
                cmd.Parameters.AddWithValue("reporter", userId);
                cmd.Parameters.AddWithValue("kind", request.Kind ?? "InformationTechnology");
                cmd.Parameters.AddWithValue("category", request.Category ?? "");
                cmd.Parameters.AddWithValue("title", request.Title ?? "");
                cmd.Parameters.AddWithValue("description", request.Description ?? "");
                cmd.Parameters.AddWithValue("affected_asset", (object?)request.AffectedAsset ?? DBNull.Value);
                cmd.Parameters.AddWithValue("severity", request.Severity ?? "Normal");
                cmd.Parameters.AddWithValue("impacts", request.ImpactsOperations);
                cmd.Parameters.AddWithValue("occurred_at", request.OccurredAt ?? DateTimeOffset.UtcNow);

                await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                {
                    await tx.RollbackAsync(cancellationToken);
                    return new(true, false, HttpStatusCode.ServiceUnavailable, null);
                }

                var row = ReadIncident(reader);
                await reader.CloseAsync();

                await using var audit = new NpgsqlCommand(
                    """
                    insert into public.metra_support_incident_audit_events (
                      incident_id, station_id, actor_user_id, event_type, from_status, to_status, note)
                    values (@incident_id, @station_id, @actor, 'submitted', null, 'Submitted', null);
                    """, conn, tx);
                audit.Parameters.AddWithValue("incident_id", id);
                audit.Parameters.AddWithValue("station_id", stationId);
                audit.Parameters.AddWithValue("actor", userId);
                await audit.ExecuteNonQueryAsync(cancellationToken);

                await tx.CommitAsync(cancellationToken);
                return new(true, true, HttpStatusCode.Created, JsonSerializer.SerializeToElement(row));
            }
            catch (PostgresException)
            {
                await tx.RollbackAsync(cancellationToken);
                return new(true, false, HttpStatusCode.ServiceUnavailable, null);
            }
        }
    }

    public async Task<SupportIncidentServiceOutcome> ListAsync(
        Guid stationId,
        int limit,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || limit is < 1 or > 100)
            return new(IsConfigured, false, null, null);

        var (conn, tx) = await NpgsqlOpsSession.BeginScopedAsync(
            _connectionString!, Guid.Empty, stationId, cancellationToken);
        await using (conn)
        await using (tx)
        {
            await using var cmd = new NpgsqlCommand(
                """
                select id, station_id, reporter_user_id, kind, category, title, description,
                       affected_asset, severity, status, impacts_operations, occurred_at,
                       assigned_to, created_at, updated_at
                from public.metra_support_incidents
                where station_id = @station_id
                order by occurred_at desc
                limit @limit;
                """, conn, tx);
            cmd.Parameters.AddWithValue("station_id", stationId);
            cmd.Parameters.AddWithValue("limit", limit);

            var rows = new List<Dictionary<string, object?>>();
            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                rows.Add(ReadIncident(reader));

            await tx.CommitAsync(cancellationToken);
            return new(true, true, HttpStatusCode.OK, JsonSerializer.SerializeToElement(rows));
        }
    }

    public async Task<SupportIncidentServiceOutcome> GetByIdAsync(
        Guid stationId,
        Guid incidentId,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || incidentId == Guid.Empty)
            return new(IsConfigured, false, null, null);

        var (conn, tx) = await NpgsqlOpsSession.BeginScopedAsync(
            _connectionString!, Guid.Empty, stationId, cancellationToken);
        await using (conn)
        await using (tx)
        {
            await using var cmd = new NpgsqlCommand(
                """
                select id, station_id, reporter_user_id, kind, category, title, description,
                       affected_asset, severity, status, impacts_operations, occurred_at,
                       assigned_to, created_at, updated_at
                from public.metra_support_incidents
                where id = @id and station_id = @station_id
                limit 1;
                """, conn, tx);
            cmd.Parameters.AddWithValue("id", incidentId);
            cmd.Parameters.AddWithValue("station_id", stationId);
            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                await tx.CommitAsync(cancellationToken);
                return new(true, false, HttpStatusCode.NotFound, null);
            }
            var row = ReadIncident(reader);
            await tx.CommitAsync(cancellationToken);
            return new(true, true, HttpStatusCode.OK, JsonSerializer.SerializeToElement(row));
        }
    }

    public async Task<SupportIncidentServiceOutcome> TransitionAsync(
        Guid userId,
        Guid stationId,
        Guid incidentId,
        SupportIncidentTransitionRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new(false, false, null, null);
        if (request.ToStatus is null ||
            !Enum.TryParse<SupportIncidentStatus>(request.ToStatus, true, out var toStatus) ||
            !Enum.IsDefined(toStatus))
            return new(true, false, HttpStatusCode.BadRequest, null);

        var permission = SupportIncidentRequestGuard.PermissionForTransition(toStatus);
        var allowed = await authorization.HasStationPermissionAsync(
            userId, stationId, permission, cancellationToken);
        if (!allowed)
            return new(true, false, HttpStatusCode.Forbidden, null);

        var (conn, tx) = await NpgsqlOpsSession.BeginScopedAsync(
            _connectionString!, userId, stationId, cancellationToken);
        await using (conn)
        await using (tx)
        {
            try
            {
                await using var select = new NpgsqlCommand(
                    """
                    select id, station_id, status
                    from public.metra_support_incidents
                    where id = @id and station_id = @station_id
                    for update;
                    """, conn, tx);
                select.Parameters.AddWithValue("id", incidentId);
                select.Parameters.AddWithValue("station_id", stationId);

                await using var reader = await select.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                {
                    await reader.CloseAsync();
                    await tx.RollbackAsync(cancellationToken);
                    return new(true, false, HttpStatusCode.NotFound, null);
                }

                var fromStatusText = reader.GetString(reader.GetOrdinal("status"));
                var assignedToOrdinal = reader.GetOrdinal("assigned_to");
                Guid? currentAssignee = reader.IsDBNull(assignedToOrdinal) ? null : reader.GetGuid(assignedToOrdinal);
                await reader.CloseAsync();

                if (!Enum.TryParse<SupportIncidentStatus>(fromStatusText, true, out var fromStatus) ||
                    !SupportIncidentPolicy.CanTransition(fromStatus, toStatus))
                {
                    await tx.RollbackAsync(cancellationToken);
                    return new(true, false, HttpStatusCode.Conflict, null);
                }

                if (toStatus is SupportIncidentStatus.Rejected or SupportIncidentStatus.Closed &&
                    string.IsNullOrWhiteSpace(request.Note))
                {
                    await tx.RollbackAsync(cancellationToken);
                    return new(true, false, HttpStatusCode.BadRequest, null);
                }

                if (toStatus == SupportIncidentStatus.Assigned)
                {
                    var assigneeId = request.AssignedTo ?? currentAssignee;
                    if (assigneeId is null || assigneeId == Guid.Empty)
                    {
                        await tx.RollbackAsync(cancellationToken);
                        return new(true, false, HttpStatusCode.BadRequest, null);
                    }
                    if (!await StationAssigneeAuthorization.CanAssignSupportIncidentAsync(
                        authorization, assigneeId.Value, stationId, cancellationToken))
                    {
                        await tx.RollbackAsync(cancellationToken);
                        return new(true, false, HttpStatusCode.Forbidden, null);
                    }
                }

                await using var update = new NpgsqlCommand(
                    """
                    update public.metra_support_incidents
                    set status = @to_status,
                        assigned_to = case
                          when @to_status = 'Assigned' then coalesce(@assigned_to, assigned_to)
                          else assigned_to end,
                        updated_at = now()
                    where id = @id and station_id = @station_id
                    returning id, station_id, reporter_user_id, kind, category, title, description,
                              affected_asset, severity, status, impacts_operations, occurred_at,
                              assigned_to, created_at, updated_at;
                    """, conn, tx);
                update.Parameters.AddWithValue("to_status", toStatus.ToString());
                update.Parameters.AddWithValue("id", incidentId);
                update.Parameters.AddWithValue("station_id", stationId);
                var assignedParam = update.Parameters.Add("assigned_to", NpgsqlDbType.Uuid);
                assignedParam.Value = request.AssignedTo is Guid g ? g : DBNull.Value;

                await using var updatedReader = await update.ExecuteReaderAsync(cancellationToken);
                if (!await updatedReader.ReadAsync(cancellationToken))
                {
                    await updatedReader.CloseAsync();
                    await tx.RollbackAsync(cancellationToken);
                    return new(true, false, HttpStatusCode.Conflict, null);
                }
                var row = ReadIncident(updatedReader);
                await updatedReader.CloseAsync();

                await using var audit = new NpgsqlCommand(
                    """
                    insert into public.metra_support_incident_audit_events (
                      incident_id, station_id, actor_user_id, event_type, from_status, to_status, note)
                    values (@incident_id, @station_id, @actor, 'status_transition', @from_status, @to_status, @note);
                    """, conn, tx);
                audit.Parameters.AddWithValue("incident_id", incidentId);
                audit.Parameters.AddWithValue("station_id", stationId);
                audit.Parameters.AddWithValue("actor", userId);
                audit.Parameters.AddWithValue("from_status", fromStatusText);
                audit.Parameters.AddWithValue("to_status", toStatus.ToString());
                audit.Parameters.AddWithValue("note", (object?)request.Note ?? DBNull.Value);
                await audit.ExecuteNonQueryAsync(cancellationToken);

                await tx.CommitAsync(cancellationToken);
                return new(true, true, HttpStatusCode.OK, JsonSerializer.SerializeToElement(row));
            }
            catch (PostgresException)
            {
                await tx.RollbackAsync(cancellationToken);
                return new(true, false, HttpStatusCode.ServiceUnavailable, null);
            }
        }
    }

    private static Dictionary<string, object?> ReadIncident(NpgsqlDataReader reader)
    {
        object? OptionalGuid(string name)
        {
            var ord = reader.GetOrdinal(name);
            return reader.IsDBNull(ord) ? null : reader.GetGuid(ord);
        }

        object? OptionalString(string name)
        {
            var ord = reader.GetOrdinal(name);
            return reader.IsDBNull(ord) ? null : reader.GetString(ord);
        }

        return new Dictionary<string, object?>
        {
            ["id"] = reader.GetGuid(reader.GetOrdinal("id")),
            ["station_id"] = reader.GetGuid(reader.GetOrdinal("station_id")),
            ["reporter_user_id"] = reader.GetGuid(reader.GetOrdinal("reporter_user_id")),
            ["kind"] = reader.GetString(reader.GetOrdinal("kind")),
            ["category"] = reader.GetString(reader.GetOrdinal("category")),
            ["title"] = reader.GetString(reader.GetOrdinal("title")),
            ["description"] = reader.GetString(reader.GetOrdinal("description")),
            ["affected_asset"] = OptionalString("affected_asset"),
            ["severity"] = reader.GetString(reader.GetOrdinal("severity")),
            ["status"] = reader.GetString(reader.GetOrdinal("status")),
            ["impacts_operations"] = reader.GetBoolean(reader.GetOrdinal("impacts_operations")),
            ["occurred_at"] = reader.GetFieldValue<DateTimeOffset>(reader.GetOrdinal("occurred_at")),
            ["assigned_to"] = OptionalGuid("assigned_to"),
            ["created_at"] = reader.GetFieldValue<DateTimeOffset>(reader.GetOrdinal("created_at")),
            ["updated_at"] = reader.GetFieldValue<DateTimeOffset>(reader.GetOrdinal("updated_at"))
        };
    }
}
