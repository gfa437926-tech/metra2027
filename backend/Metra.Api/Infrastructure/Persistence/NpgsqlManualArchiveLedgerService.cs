using System.Net;
using Metra.Api.Domain.Archive;
using Metra.Api.Features.Archive;
using Npgsql;

namespace Metra.Api.Infrastructure.Persistence;

/// <summary>
/// Durable station-scoped manual Excel archive confirmations via MetraOps.
/// Requires approved table <c>metra_manual_archive_confirmations</c> (Phase E).
/// Does not store observation payloads and does not touch any archive database of records.
/// </summary>
public sealed class NpgsqlManualArchiveLedgerService(IConfiguration configuration) : IManualArchiveLedgerService
{
    private readonly string? _connectionString = configuration.GetConnectionString("MetraOps");

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_connectionString);

    public async Task<ManualArchiveServiceOutcome> ListAsync(Guid stationId, int limit, CancellationToken ct)
    {
        if (!IsConfigured)
            return new ManualArchiveServiceOutcome(false, HttpStatusCode.ServiceUnavailable, null, "archive_ledger_unconfigured");
        if (stationId == Guid.Empty || limit is < 1 or > 200)
            return new ManualArchiveServiceOutcome(false, HttpStatusCode.BadRequest, null, "invalid_request");

        try
        {
            // List uses a read-only scoped session bound to the station for RLS-ready deployments.
            var (conn, tx) = await NpgsqlOpsSession.BeginScopedAsync(
                _connectionString!, Guid.Empty, stationId, ct);
            await using (conn)
            await using (tx)
            {
                await using var cmd = new NpgsqlCommand(
                    """
                    select id, station_id, actor_user_id, report_kind,
                           period_start_utc, period_end_utc, excel_file_name, note, confirmed_at_utc
                    from public.metra_manual_archive_confirmations
                    where station_id = @station_id
                    order by confirmed_at_utc desc
                    limit @limit
                    """,
                    conn, tx);
                cmd.Parameters.AddWithValue("station_id", stationId);
                cmd.Parameters.AddWithValue("limit", limit);

                var rows = new List<ManualArchiveConfirmation>();
                await using var reader = await cmd.ExecuteReaderAsync(ct);
                while (await reader.ReadAsync(ct))
                {
                    rows.Add(ReadRow(reader));
                }

                await tx.CommitAsync(ct);
                return new ManualArchiveServiceOutcome(true, HttpStatusCode.OK, rows);
            }
        }
        catch (PostgresException ex) when (ex.SqlState is "42P01" or "42501")
        {
            // undefined_table or insufficient_privilege — migration not applied / role not granted
            return new ManualArchiveServiceOutcome(
                false, HttpStatusCode.ServiceUnavailable, null, "archive_ledger_not_provisioned");
        }
        catch (Exception)
        {
            return new ManualArchiveServiceOutcome(
                false, HttpStatusCode.ServiceUnavailable, null, "archive_ledger_unavailable");
        }
    }

    public async Task<ManualArchiveServiceOutcome> ConfirmAsync(
        Guid stationId, Guid actorUserId, ManualArchiveConfirmRequest request, CancellationToken ct)
    {
        if (!IsConfigured)
            return new ManualArchiveServiceOutcome(false, HttpStatusCode.ServiceUnavailable, null, "archive_ledger_unconfigured");
        if (!DateOnly.TryParse(request.PeriodStartUtc, out var start) ||
            !DateOnly.TryParse(request.PeriodEndUtc, out var end))
        {
            return new ManualArchiveServiceOutcome(false, HttpStatusCode.BadRequest, null, "invalid_period");
        }

        var validation = ManualArchiveLedgerPolicy.ValidateRequest(
            stationId, actorUserId, request.ReportKind, start, end, request.ExcelFileName, request.Note);
        if (validation is not null)
            return new ManualArchiveServiceOutcome(false, HttpStatusCode.BadRequest, null, validation);

        var kind = request.ReportKind!.Trim().ToLowerInvariant();
        var fileName = ManualArchiveLedgerPolicy.NormalizeFileName(request.ExcelFileName!);
        var note = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim();

        try
        {
            var (conn, tx) = await NpgsqlOpsSession.BeginScopedAsync(
                _connectionString!, actorUserId, stationId, ct);
            await using (conn)
            await using (tx)
            {
                await using var cmd = new NpgsqlCommand(
                    """
                    insert into public.metra_manual_archive_confirmations (
                        station_id, actor_user_id, report_kind,
                        period_start_utc, period_end_utc, excel_file_name, note
                    ) values (
                        @station_id, @actor_user_id, @report_kind,
                        @period_start, @period_end, @file_name, @note
                    )
                    returning id, station_id, actor_user_id, report_kind,
                              period_start_utc, period_end_utc, excel_file_name, note, confirmed_at_utc
                    """,
                    conn, tx);
                cmd.Parameters.AddWithValue("station_id", stationId);
                cmd.Parameters.AddWithValue("actor_user_id", actorUserId);
                cmd.Parameters.AddWithValue("report_kind", kind);
                cmd.Parameters.AddWithValue("period_start", start);
                cmd.Parameters.AddWithValue("period_end", end);
                cmd.Parameters.AddWithValue("file_name", fileName);
                cmd.Parameters.AddWithValue("note", (object?)note ?? DBNull.Value);

                await using var reader = await cmd.ExecuteReaderAsync(ct);
                if (!await reader.ReadAsync(ct))
                {
                    await tx.RollbackAsync(ct);
                    return new ManualArchiveServiceOutcome(
                        false, HttpStatusCode.ServiceUnavailable, null, "archive_ledger_write_failed");
                }

                var entry = ReadRow(reader);
                await reader.CloseAsync();
                await tx.CommitAsync(ct);
                return new ManualArchiveServiceOutcome(true, HttpStatusCode.Created, entry);
            }
        }
        catch (PostgresException ex) when (ex.SqlState is "23505")
        {
            return new ManualArchiveServiceOutcome(
                false, HttpStatusCode.Conflict, null, "duplicate_archive_confirmation");
        }
        catch (PostgresException ex) when (ex.SqlState is "42P01" or "42501")
        {
            return new ManualArchiveServiceOutcome(
                false, HttpStatusCode.ServiceUnavailable, null, "archive_ledger_not_provisioned");
        }
        catch (Exception)
        {
            return new ManualArchiveServiceOutcome(
                false, HttpStatusCode.ServiceUnavailable, null, "archive_ledger_unavailable");
        }
    }

    public async Task<ManualArchiveServiceOutcome> MonthlySummaryAsync(
        Guid stationId, int year, int month, CancellationToken ct)
    {
        if (!IsConfigured)
            return new ManualArchiveServiceOutcome(false, HttpStatusCode.ServiceUnavailable, null, "archive_ledger_unconfigured");
        if (stationId == Guid.Empty || year is < 2000 or > 2100 || month is < 1 or > 12)
            return new ManualArchiveServiceOutcome(false, HttpStatusCode.BadRequest, null, "invalid_month");

        try
        {
            var (conn, tx) = await NpgsqlOpsSession.BeginScopedAsync(
                _connectionString!, Guid.Empty, stationId, ct);
            await using (conn)
            await using (tx)
            {
                await using var cmd = new NpgsqlCommand(
                    """
                    select count(*)::int,
                           coalesce(array_agg(distinct report_kind) filter (where report_kind is not null), '{}')
                    from public.metra_manual_archive_confirmations
                    where station_id = @station_id
                      and extract(year from period_start_utc) = @year
                      and extract(month from period_start_utc) = @month
                    """,
                    conn, tx);
                cmd.Parameters.AddWithValue("station_id", stationId);
                cmd.Parameters.AddWithValue("year", year);
                cmd.Parameters.AddWithValue("month", month);

                await using var reader = await cmd.ExecuteReaderAsync(ct);
                await reader.ReadAsync(ct);
                var count = reader.GetInt32(0);
                var kinds = reader.IsDBNull(1)
                    ? Array.Empty<string>()
                    : (reader.GetValue(1) as string[] ?? Array.Empty<string>());
                await reader.CloseAsync();
                await tx.CommitAsync(ct);

                var summary = new ManualArchiveMonthlySummary(year, month, count, kinds.OrderBy(x => x).ToArray());
                return new ManualArchiveServiceOutcome(true, HttpStatusCode.OK, summary);
            }
        }
        catch (PostgresException ex) when (ex.SqlState is "42P01" or "42501")
        {
            return new ManualArchiveServiceOutcome(
                false, HttpStatusCode.ServiceUnavailable, null, "archive_ledger_not_provisioned");
        }
        catch (Exception)
        {
            return new ManualArchiveServiceOutcome(
                false, HttpStatusCode.ServiceUnavailable, null, "archive_ledger_unavailable");
        }
    }

    private static ManualArchiveConfirmation ReadRow(NpgsqlDataReader reader) =>
        new(
            reader.GetGuid(0),
            reader.GetGuid(1),
            reader.GetGuid(2),
            reader.GetString(3),
            DateOnly.FromDateTime(reader.GetFieldValue<DateTime>(4)),
            DateOnly.FromDateTime(reader.GetFieldValue<DateTime>(5)),
            reader.GetString(6),
            reader.IsDBNull(7) ? null : reader.GetString(7),
            new DateTimeOffset(DateTime.SpecifyKind(reader.GetFieldValue<DateTime>(8), DateTimeKind.Utc)));
}
