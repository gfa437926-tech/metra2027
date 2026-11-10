namespace Metra.Api.Domain.Archive;

/// <summary>
/// Administrative confirmation that an auditor archived an Excel export manually.
/// Does not transfer observation data to any archive database.
/// </summary>
public sealed record ManualArchiveConfirmation(
    Guid Id,
    Guid StationId,
    Guid ActorUserId,
    string ReportKind,
    DateOnly PeriodStartUtc,
    DateOnly PeriodEndUtc,
    string ExcelFileName,
    string? Note,
    DateTimeOffset ConfirmedAtUtc);

public static class ManualArchiveLedgerPolicy
{
    public static readonly HashSet<string> AllowedReportKinds = new(StringComparer.OrdinalIgnoreCase)
    {
        "hourly",
        "daily",
        "monthly",
        "rainfall",
        "climate",
        "other"
    };

    public static string NormalizeFileName(string fileName) =>
        fileName.Trim();

    public static string DuplicateKey(
        Guid stationId,
        string reportKind,
        DateOnly periodStartUtc,
        DateOnly periodEndUtc,
        string excelFileName) =>
        string.Join('|',
            stationId.ToString("D"),
            reportKind.Trim().ToLowerInvariant(),
            periodStartUtc.ToString("yyyy-MM-dd"),
            periodEndUtc.ToString("yyyy-MM-dd"),
            NormalizeFileName(excelFileName).ToLowerInvariant());

    public static string? ValidateRequest(
        Guid stationId,
        Guid actorUserId,
        string? reportKind,
        DateOnly? periodStartUtc,
        DateOnly? periodEndUtc,
        string? excelFileName,
        string? note)
    {
        if (stationId == Guid.Empty || actorUserId == Guid.Empty)
            return "invalid_actor_or_station";
        if (string.IsNullOrWhiteSpace(reportKind) || !AllowedReportKinds.Contains(reportKind.Trim()))
            return "invalid_report_kind";
        if (periodStartUtc is null || periodEndUtc is null)
            return "period_required";
        if (periodEndUtc < periodStartUtc)
            return "invalid_period_range";
        if (string.IsNullOrWhiteSpace(excelFileName) || excelFileName.Trim().Length > 260)
            return "invalid_excel_file_name";
        if (excelFileName.IndexOfAny(System.IO.Path.GetInvalidFileNameChars()) >= 0)
            return "invalid_excel_file_name";
        if (note is { Length: > 2000 })
            return "note_too_long";
        if (note is not null && note.Any(ch => char.IsControl(ch) && ch is not '\r' and not '\n' and not '\t'))
            return "invalid_note";
        return null;
    }
}

public sealed record ManualArchiveMonthlySummary(
    int Year,
    int Month,
    int ConfirmationCount,
    IReadOnlyList<string> ReportKinds);
