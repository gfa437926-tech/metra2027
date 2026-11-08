using System.Data;
using System.Net;
using System.Text.Json;
using Metra.Api.Domain.Maintenance;
using Metra.Api.Features.Maintenance;
using Metra.Api.Security;
using Npgsql;
using NpgsqlTypes;

namespace Metra.Api.Infrastructure.Persistence;

/// <summary>
/// Station-scoped equipment fault persistence over Npgsql.
/// Activated only when ConnectionStrings:MetraOps is configured.
/// Every transaction sets role metra_ops_faults and LOCAL app.station_id / app.user_id
/// so RLS + least privilege apply; pooled connections cannot leak prior request context.
/// </summary>
public sealed class NpgsqlEquipmentFaultService(
    IConfiguration configuration,
    IStationAuthorizationService authorization) : IEquipmentFaultService
{
    private readonly string? _connectionString = configuration.GetConnectionString("MetraOps");

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task<EquipmentFaultServiceOutcome> SubmitAsync(
        Guid userId,
        Guid stationId,
        EquipmentFaultSubmitRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new(false, false, null, null);

        var allowed = await authorization.HasStationPermissionAsync(
            userId, stationId, "equipment_fault.create", cancellationToken);
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
                    insert into public.metra_equipment_faults (
                      id, station_id, reporter_user_id, equipment_category, equipment_name,
                      description, severity, status, is_operationally_blocking, occurred_at,
                      progress_percent, created_at, updated_at)
                    values (
                      @id, @station_id, @reporter, @category, @name,
                      @description, @severity, 'Submitted', @blocking, @occurred_at,
                      0, now(), now())
                    returning id, station_id, reporter_user_id, equipment_category, equipment_name,
                              description, severity, status, is_operationally_blocking, occurred_at,
                              assigned_to, progress_percent, progress_note, created_at, updated_at;
                    """, conn, tx);
                cmd.Parameters.AddWithValue("id", id);
                cmd.Parameters.AddWithValue("station_id", stationId);
                cmd.Parameters.AddWithValue("reporter", userId);
                cmd.Parameters.AddWithValue("category", request.EquipmentCategory ?? "");
                cmd.Parameters.AddWithValue("name", request.EquipmentName ?? "");
                cmd.Parameters.AddWithValue("description", request.Description ?? "");
                cmd.Parameters.AddWithValue("severity", request.Severity ?? "High");
                cmd.Parameters.AddWithValue("blocking", request.IsOperationallyBlocking);
                cmd.Parameters.AddWithValue("occurred_at", request.OccurredAt ?? DateTimeOffset.UtcNow);

                await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                {
                    await tx.RollbackAsync(cancellationToken);
                    return new(true, false, HttpStatusCode.ServiceUnavailable, null);
                }

                var row = ReadFault(reader);
                await reader.CloseAsync();

                await using var audit = new NpgsqlCommand(
                    """
                    insert into public.metra_equipment_fault_audit_events (
                      fault_id, station_id, actor_user_id, event_type, from_status, to_status, note)
                    values (@fault_id, @station_id, @actor, 'submitted', null, 'Submitted', null);
                    """, conn, tx);
                audit.Parameters.AddWithValue("fault_id", id);
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

    public async Task<EquipmentFaultServiceOutcome> ListAsync(
        Guid stationId,
        int limit,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || limit is < 1 or > 100)
            return new(IsConfigured, false, null, null);

        // Read path still binds station context so RLS cannot return other stations.
        var (conn, tx) = await NpgsqlOpsSession.BeginScopedAsync(
            _connectionString!, Guid.Empty, stationId, cancellationToken);
        await using (conn)
        await using (tx)
        {
            await using var cmd = new NpgsqlCommand(
                """
                select id, station_id, reporter_user_id, equipment_category, equipment_name,
                       description, severity, status, is_operationally_blocking, occurred_at,
                       assigned_to, progress_percent, progress_note, created_at, updated_at
                from public.metra_equipment_faults
                where station_id = @station_id
                order by occurred_at desc
                limit @limit;
                """, conn, tx);
            cmd.Parameters.AddWithValue("station_id", stationId);
            cmd.Parameters.AddWithValue("limit", limit);

            var rows = new List<Dictionary<string, object?>>();
            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
                rows.Add(ReadFault(reader));

            await tx.CommitAsync(cancellationToken);
            return new(true, true, HttpStatusCode.OK, JsonSerializer.SerializeToElement(rows));
        }
    }

    public async Task<EquipmentFaultServiceOutcome> GetByIdAsync(
        Guid stationId,
        Guid faultId,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || faultId == Guid.Empty)
            return new(IsConfigured, false, null, null);

        var (conn, tx) = await NpgsqlOpsSession.BeginScopedAsync(
            _connectionString!, Guid.Empty, stationId, cancellationToken);
        await using (conn)
        await using (tx)
        {
            await using var cmd = new NpgsqlCommand(
                """
                select id, station_id, reporter_user_id, equipment_category, equipment_name,
                       description, severity, status, is_operationally_blocking, occurred_at,
                       assigned_to, progress_percent, progress_note, created_at, updated_at
                from public.metra_equipment_faults
                where id = @id and station_id = @station_id
                limit 1;
                """, conn, tx);
            cmd.Parameters.AddWithValue("id", faultId);
            cmd.Parameters.AddWithValue("station_id", stationId);

            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
            if (!await reader.ReadAsync(cancellationToken))
            {
                await tx.CommitAsync(cancellationToken);
                return new(true, false, HttpStatusCode.NotFound, null);
            }

            var row = ReadFault(reader);
            await tx.CommitAsync(cancellationToken);
            return new(true, true, HttpStatusCode.OK, JsonSerializer.SerializeToElement(row));
        }
    }

    public async Task<EquipmentFaultServiceOutcome> TransitionAsync(
        Guid userId,
        Guid stationId,
        Guid faultId,
        EquipmentFaultTransitionRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new(false, false, null, null);
        if (request.ToStatus is null ||
            !Enum.TryParse<EquipmentFaultStatus>(request.ToStatus, true, out var toStatus) ||
            !Enum.IsDefined(toStatus))
            return new(true, false, HttpStatusCode.BadRequest, null);

        var permission = EquipmentFaultRequestGuard.PermissionForTransition(toStatus);
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
                    select id, station_id, status, assigned_to, progress_percent
                    from public.metra_equipment_faults
                    where id = @id and station_id = @station_id
                    for update;
                    """, conn, tx);
                select.Parameters.AddWithValue("id", faultId);
                select.Parameters.AddWithValue("station_id", stationId);

                await using var reader = await select.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                {
                    await reader.CloseAsync();
                    await tx.RollbackAsync(cancellationToken);
                    return new(true, false, HttpStatusCode.NotFound, null);
                }

                var fromStatusText = reader.GetString(reader.GetOrdinal("status"));
                var progress = reader.GetInt32(reader.GetOrdinal("progress_percent"));
                await reader.CloseAsync();

                if (!Enum.TryParse<EquipmentFaultStatus>(fromStatusText, true, out var fromStatus) ||
                    !EquipmentFaultPolicy.CanTransition(fromStatus, toStatus))
                {
                    await tx.RollbackAsync(cancellationToken);
                    return new(true, false, HttpStatusCode.Conflict, null);
                }

                if (toStatus is EquipmentFaultStatus.Rejected or EquipmentFaultStatus.Closed &&
                    string.IsNullOrWhiteSpace(request.Note))
                {
                    await tx.RollbackAsync(cancellationToken);
                    return new(true, false, HttpStatusCode.BadRequest, null);
                }

                if (toStatus == EquipmentFaultStatus.Resolved && (request.ProgressPercent ?? progress) != 100)
                {
                    await tx.RollbackAsync(cancellationToken);
                    return new(true, false, HttpStatusCode.BadRequest, null);
                }

                await using var update = new NpgsqlCommand(
                    """
                    update public.metra_equipment_faults
                    set status = @to_status,
                        assigned_to = case
                          when @to_status = 'Assigned' then coalesce(@assigned_to, assigned_to)
                          else assigned_to end,
                        progress_percent = coalesce(@progress, progress_percent),
                        progress_note = coalesce(@note, progress_note),
                        updated_at = now()
                    where id = @id and station_id = @station_id
                    returning id, station_id, reporter_user_id, equipment_category, equipment_name,
                              description, severity, status, is_operationally_blocking, occurred_at,
                              assigned_to, progress_percent, progress_note, created_at, updated_at;
                    """, conn, tx);
                update.Parameters.AddWithValue("to_status", toStatus.ToString());
                update.Parameters.AddWithValue("id", faultId);
                update.Parameters.AddWithValue("station_id", stationId);
                update.Parameters.AddWithValue("progress", (object?)request.ProgressPercent ?? DBNull.Value);
                update.Parameters.AddWithValue("note", (object?)request.Note ?? DBNull.Value);
                var assignedParam = update.Parameters.Add("assigned_to", NpgsqlDbType.Uuid);
                assignedParam.Value = request.AssignedTo is Guid g ? g : DBNull.Value;

                await using var updatedReader = await update.ExecuteReaderAsync(cancellationToken);
                if (!await updatedReader.ReadAsync(cancellationToken))
                {
                    await updatedReader.CloseAsync();
                    await tx.RollbackAsync(cancellationToken);
                    return new(true, false, HttpStatusCode.Conflict, null);
                }
                var row = ReadFault(updatedReader);
                await updatedReader.CloseAsync();

                await using var audit = new NpgsqlCommand(
                    """
                    insert into public.metra_equipment_fault_audit_events (
                      fault_id, station_id, actor_user_id, event_type, from_status, to_status, note)
                    values (@fault_id, @station_id, @actor, 'status_transition', @from_status, @to_status, @note);
                    """, conn, tx);
                audit.Parameters.AddWithValue("fault_id", faultId);
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

    private static Dictionary<string, object?> ReadFault(NpgsqlDataReader reader)
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
            ["equipment_category"] = reader.GetString(reader.GetOrdinal("equipment_category")),
            ["equipment_name"] = reader.GetString(reader.GetOrdinal("equipment_name")),
            ["description"] = reader.GetString(reader.GetOrdinal("description")),
            ["severity"] = reader.GetString(reader.GetOrdinal("severity")),
            ["status"] = reader.GetString(reader.GetOrdinal("status")),
            ["is_operationally_blocking"] = reader.GetBoolean(reader.GetOrdinal("is_operationally_blocking")),
            ["occurred_at"] = reader.GetFieldValue<DateTimeOffset>(reader.GetOrdinal("occurred_at")),
            ["assigned_to"] = OptionalGuid("assigned_to"),
            ["progress_percent"] = reader.GetInt32(reader.GetOrdinal("progress_percent")),
            ["progress_note"] = OptionalString("progress_note"),
            ["created_at"] = reader.GetFieldValue<DateTimeOffset>(reader.GetOrdinal("created_at")),
            ["updated_at"] = reader.GetFieldValue<DateTimeOffset>(reader.GetOrdinal("updated_at"))
        };
    }
}
