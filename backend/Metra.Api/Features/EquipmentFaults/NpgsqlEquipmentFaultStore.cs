using System.Data;
using Npgsql;

namespace Metra.Api.Features.EquipmentFaults;

/// <summary>
/// Direct PostgreSQL adapter for Equipment Faults. Every operation assumes the
/// dedicated login can SET ROLE to metra_equipment_faults_runtime. Actor/station
/// context is transaction-local to prevent pooled-connection context leakage.
/// </summary>
public sealed class NpgsqlEquipmentFaultStore(NpgsqlDataSource dataSource) :
    IEquipmentFaultStationReader,
    IEquipmentFaultReadStore,
    IEquipmentFaultTransitionWriter,
    IEquipmentFaultSubmissionWriter
{
    private const string RuntimeRole = "metra_equipment_faults_runtime";

    public async Task<Guid?> GetOwningStationIdAsync(
        Guid actorId, Guid stationId, Guid faultId, CancellationToken cancellationToken)
    {
        if (!ValidContext(actorId, stationId, faultId))
            return null;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await SetContextAsync(connection, transaction, actorId, stationId, string.Empty, cancellationToken);

        await using var command = new NpgsqlCommand(
            """
            select station_id
            from public.equipment_faults
            where id = @fault_id and station_id = @station_id
            """, connection, transaction);
        command.Parameters.AddWithValue("fault_id", faultId);
        command.Parameters.AddWithValue("station_id", stationId);
        var value = await command.ExecuteScalarAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return value is Guid persistedStation ? persistedStation : null;
    }

    public async Task<EquipmentFaultListPage> GetPageAsync(
        Guid actorId,
        Guid stationId,
        EquipmentFaultListQuery query,
        EquipmentFaultListWindow window,
        CancellationToken cancellationToken = default)
    {
        if (!ValidContext(actorId, stationId))
            throw new ArgumentException("A valid actor and station context is required.");

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(
            IsolationLevel.RepeatableRead, cancellationToken);
        await SetContextAsync(connection, transaction, actorId, stationId, string.Empty, cancellationToken);

        var predicates = new List<string> { "station_id = @station_id" };
        await using var countCommand = new NpgsqlCommand { Connection = connection, Transaction = transaction };
        countCommand.Parameters.AddWithValue("station_id", stationId);
        AddFilters(query, predicates, countCommand);
        countCommand.CommandText = $"select count(*) from public.equipment_faults where {string.Join(" and ", predicates)}";
        var total = (long)(await countCommand.ExecuteScalarAsync(cancellationToken) ?? 0L);

        await using var pageCommand = new NpgsqlCommand { Connection = connection, Transaction = transaction };
        foreach (NpgsqlParameter parameter in countCommand.Parameters)
            pageCommand.Parameters.AddWithValue(parameter.ParameterName, parameter.Value);

        var order = query.Sort == EquipmentFaultListSort.OccurredAtAscending
            ? "occurred_at asc, id asc"
            : "occurred_at desc, id desc";
        pageCommand.CommandText = $"""
            select id, station_id, equipment_category, equipment_name, severity, status, occurred_at
            from public.equipment_faults
            where {string.Join(" and ", predicates)}
            order by {order}
            limit @limit offset @offset
            """;
        pageCommand.Parameters.AddWithValue("limit", window.PageSize);
        pageCommand.Parameters.AddWithValue("offset", window.Offset);

        var items = new List<EquipmentFaultListItem>();
        await using (var reader = await pageCommand.ExecuteReaderAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                items.Add(new EquipmentFaultListItem(
                    reader.GetGuid(0), reader.GetGuid(1), reader.GetString(2), reader.GetString(3),
                    Enum.Parse<EquipmentFaultSeverity>(reader.GetString(4), false),
                    Enum.Parse<EquipmentFaultStatus>(reader.GetString(5), false),
                    reader.GetFieldValue<DateTimeOffset>(6)));
            }
        }

        await transaction.CommitAsync(cancellationToken);
        return new EquipmentFaultListPage(items, total, window.Page, window.PageSize);
    }

    public async Task<EquipmentFaultDetail?> GetDetailAsync(
        Guid actorId, Guid faultId, Guid stationId, CancellationToken cancellationToken = default)
    {
        if (!ValidContext(actorId, stationId, faultId))
            return null;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await SetContextAsync(connection, transaction, actorId, stationId, string.Empty, cancellationToken);

        await using var command = new NpgsqlCommand(
            """
            select id, station_id, reporter_id, equipment_category, equipment_name,
                   description, severity, status, occurred_at
            from public.equipment_faults
            where id = @fault_id and station_id = @station_id
            """, connection, transaction);
        command.Parameters.AddWithValue("fault_id", faultId);
        command.Parameters.AddWithValue("station_id", stationId);

        EquipmentFaultDetail? detail = null;
        await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
        {
            if (await reader.ReadAsync(cancellationToken))
            {
                detail = new EquipmentFaultDetail(
                    reader.GetGuid(0), reader.GetGuid(1), reader.GetGuid(2),
                    reader.GetString(3), reader.GetString(4), reader.GetString(5),
                    Enum.Parse<EquipmentFaultSeverity>(reader.GetString(6), false),
                    Enum.Parse<EquipmentFaultStatus>(reader.GetString(7), false),
                    reader.GetFieldValue<DateTimeOffset>(8));
            }
        }

        await transaction.CommitAsync(cancellationToken);
        return detail;
    }

    public async Task<EquipmentFaultTransitionWriteResult> TryTransitionAsync(
        Guid faultId,
        Guid expectedStationId,
        EquipmentFaultStatus expectedCurrentStatus,
        EquipmentFaultStatus nextStatus,
        Guid actorId,
        string reason,
        CancellationToken cancellationToken = default)
    {
        if (!ValidContext(actorId, expectedStationId, faultId) ||
            !Enum.IsDefined(expectedCurrentStatus) || !Enum.IsDefined(nextStatus) ||
            !EquipmentFaultPolicy.TryGetRequiredPermission(expectedCurrentStatus, nextStatus, out _) ||
            string.IsNullOrWhiteSpace(reason) || reason != reason.Trim() || reason.Length is < 5 or > 1000)
            return EquipmentFaultTransitionWriteResult.Forbidden;

        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await SetContextAsync(connection, transaction, actorId, expectedStationId, reason, cancellationToken);

        await using var read = new NpgsqlCommand(
            """
            select status
            from public.equipment_faults
            where id = @fault_id and station_id = @station_id
            for update
            """, connection, transaction);
        read.Parameters.AddWithValue("fault_id", faultId);
        read.Parameters.AddWithValue("station_id", expectedStationId);
        var current = await read.ExecuteScalarAsync(cancellationToken);
        if (current is not string currentStatus)
        {
            await transaction.RollbackAsync(cancellationToken);
            return EquipmentFaultTransitionWriteResult.NotFoundOrWrongStation;
        }

        if (!string.Equals(currentStatus, expectedCurrentStatus.ToString(), StringComparison.Ordinal))
        {
            await transaction.RollbackAsync(cancellationToken);
            return EquipmentFaultTransitionWriteResult.Conflict;
        }

        await using var update = new NpgsqlCommand(
            """
            update public.equipment_faults
            set status = @next_status
            where id = @fault_id and station_id = @station_id and status = @expected_status
            """, connection, transaction);
        update.Parameters.AddWithValue("next_status", nextStatus.ToString());
        update.Parameters.AddWithValue("fault_id", faultId);
        update.Parameters.AddWithValue("station_id", expectedStationId);
        update.Parameters.AddWithValue("expected_status", expectedCurrentStatus.ToString());
        var affected = await update.ExecuteNonQueryAsync(cancellationToken);
        if (affected != 1)
        {
            await transaction.RollbackAsync(cancellationToken);
            return EquipmentFaultTransitionWriteResult.Conflict;
        }

        // The AFTER trigger inserts the audit event in this same transaction.
        await transaction.CommitAsync(cancellationToken);
        return EquipmentFaultTransitionWriteResult.Applied;
    }

    public async Task<Guid> CreateAsync(
        Guid actorId,
        Guid stationId,
        EquipmentFaultSubmission submission,
        CancellationToken cancellationToken = default)
    {
        if (!ValidContext(actorId, stationId) ||
            EquipmentFaultPolicy.ValidateSubmission(submission, DateTimeOffset.UtcNow) is not null)
            throw new ArgumentException("Invalid equipment fault submission.");

        const string reason = "إنشاء بلاغ عطل";
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await SetContextAsync(connection, transaction, actorId, stationId, reason, cancellationToken);

        await using var command = new NpgsqlCommand(
            """
            insert into public.equipment_faults
              (station_id, reporter_id, equipment_category, equipment_name, description,
               severity, status, occurred_at, is_operationally_blocking)
            values
              (@station_id, @reporter_id, @category, @name, @description,
               @severity, 'Submitted', @occurred_at, @blocking)
            returning id
            """, connection, transaction);
        command.Parameters.AddWithValue("station_id", stationId);
        command.Parameters.AddWithValue("reporter_id", actorId);
        command.Parameters.AddWithValue("category", submission.EquipmentCategory!);
        command.Parameters.AddWithValue("name", submission.EquipmentName!);
        command.Parameters.AddWithValue("description", submission.Description!);
        command.Parameters.AddWithValue("severity", submission.Severity.ToString());
        command.Parameters.AddWithValue("occurred_at", submission.OccurredAt!.Value);
        command.Parameters.AddWithValue("blocking", submission.IsOperationallyBlocking);
        var id = (Guid)(await command.ExecuteScalarAsync(cancellationToken)
            ?? throw new InvalidOperationException("Fault insert returned no identifier."));
        await transaction.CommitAsync(cancellationToken);
        return id;
    }

    private static void AddFilters(
        EquipmentFaultListQuery query, List<string> predicates, NpgsqlCommand command)
    {
        if (query.Status is { } status)
        {
            predicates.Add("status = @status");
            command.Parameters.AddWithValue("status", status.ToString());
        }
        if (query.Severity is { } severity)
        {
            predicates.Add("severity = @severity");
            command.Parameters.AddWithValue("severity", severity.ToString());
        }
        if (query.OccurredFrom is { } from)
        {
            predicates.Add("occurred_at >= @occurred_from");
            command.Parameters.AddWithValue("occurred_from", from);
        }
        if (query.OccurredTo is { } to)
        {
            predicates.Add("occurred_at <= @occurred_to");
            command.Parameters.AddWithValue("occurred_to", to);
        }
    }

    private static async Task SetContextAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        Guid actorId,
        Guid stationId,
        string reason,
        CancellationToken cancellationToken)
    {
        await using (var role = new NpgsqlCommand($"set local role {RuntimeRole}", connection, transaction))
            await role.ExecuteNonQueryAsync(cancellationToken);

        await using var context = new NpgsqlCommand(
            """
            select set_config('metra.actor_id', @actor_id, true),
                   set_config('metra.station_id', @station_id, true),
                   set_config('metra.reason', @reason, true)
            """, connection, transaction);
        context.Parameters.AddWithValue("actor_id", actorId.ToString());
        context.Parameters.AddWithValue("station_id", stationId.ToString());
        context.Parameters.AddWithValue("reason", reason);
        await context.ExecuteNonQueryAsync(cancellationToken);
    }

    private static bool ValidContext(Guid actorId, Guid stationId, Guid? resourceId = null) =>
        actorId != Guid.Empty && stationId != Guid.Empty &&
        (resourceId is null || resourceId != Guid.Empty);
}
