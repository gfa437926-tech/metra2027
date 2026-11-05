namespace Metra.Api.Domain.Maintenance;

/// <summary>
/// Domain contract for an equipment fault report. This type is deliberately
/// persistence-agnostic: it does not assume or modify any Supabase schema.
/// </summary>
public sealed record EquipmentFaultReport(
    Guid StationId,
    Guid ReporterUserId,
    string EquipmentCategory,
    string EquipmentName,
    string Description,
    EquipmentFaultSeverity Severity,
    DateTimeOffset OccurredAt,
    bool IsOperationallyBlocking);

public enum EquipmentFaultSeverity
{
    Low,
    Medium,
    High,
    Critical
}

public enum EquipmentFaultStatus
{
    Submitted,
    UnderReview,
    Assigned,
    InProgress,
    Resolved,
    Closed,
    Rejected
}

public static class EquipmentFaultPolicy
{
    private static readonly IReadOnlyDictionary<EquipmentFaultStatus, EquipmentFaultStatus[]> AllowedTransitions =
        new Dictionary<EquipmentFaultStatus, EquipmentFaultStatus[]>
        {
            [EquipmentFaultStatus.Submitted] = [EquipmentFaultStatus.UnderReview, EquipmentFaultStatus.Rejected],
            [EquipmentFaultStatus.UnderReview] = [EquipmentFaultStatus.Assigned, EquipmentFaultStatus.Rejected],
            [EquipmentFaultStatus.Assigned] = [EquipmentFaultStatus.InProgress, EquipmentFaultStatus.UnderReview],
            [EquipmentFaultStatus.InProgress] = [EquipmentFaultStatus.Resolved, EquipmentFaultStatus.Assigned],
            [EquipmentFaultStatus.Resolved] = [EquipmentFaultStatus.Closed, EquipmentFaultStatus.InProgress],
            [EquipmentFaultStatus.Closed] = [],
            [EquipmentFaultStatus.Rejected] = []
        };

    public static IReadOnlyList<ValidationIssue> Validate(EquipmentFaultReport report, DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(report);
        var issues = new List<ValidationIssue>();

        if (report.StationId == Guid.Empty)
            issues.Add(new(nameof(report.StationId), "يجب تحديد محطة صحيحة."));
        if (report.ReporterUserId == Guid.Empty)
            issues.Add(new(nameof(report.ReporterUserId), "هوية المبلّغ مطلوبة."));
        if (!Enum.IsDefined(report.Severity))
            issues.Add(new(nameof(report.Severity), "درجة شدة العطل غير معروفة."));

        ValidateText(report.EquipmentCategory, nameof(report.EquipmentCategory), 2, 80, "تصنيف المعدة", issues);
        ValidateText(report.EquipmentName, nameof(report.EquipmentName), 2, 120, "اسم المعدة", issues);
        ValidateText(report.Description, nameof(report.Description), 10, 4000, "وصف العطل", issues);

        if (report.OccurredAt == default || report.OccurredAt > now.AddMinutes(5))
            issues.Add(new(nameof(report.OccurredAt), "وقت حدوث العطل غير صالح أو يقع في المستقبل."));

        if (report.IsOperationallyBlocking && report.Severity is EquipmentFaultSeverity.Low or EquipmentFaultSeverity.Medium)
            issues.Add(new(nameof(report.Severity), "العطل الذي يوقف العمل يجب تصنيفه بدرجة عالية أو حرجة."));

        return issues;
    }

    public static bool CanTransition(EquipmentFaultStatus current, EquipmentFaultStatus next)
        => Enum.IsDefined(current) &&
           Enum.IsDefined(next) &&
           AllowedTransitions.TryGetValue(current, out var allowed) &&
           allowed.Contains(next);

    private static void ValidateText(
        string? value,
        string field,
        int minimumLength,
        int maximumLength,
        string label,
        List<ValidationIssue> issues)
    {
        var normalized = value?.Trim();
        if (string.IsNullOrWhiteSpace(normalized) ||
            normalized.Length < minimumLength ||
            normalized.Length > maximumLength)
        {
            issues.Add(new(field, $"يجب إدخال {label} بطول من {minimumLength} إلى {maximumLength} محرفاً."));
        }
    }
}
