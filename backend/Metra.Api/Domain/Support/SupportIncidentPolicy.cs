using Metra.Api.Domain.Observations;

namespace Metra.Api.Domain.Support;

/// <summary>
/// Shared domain rules for station-reported IT and telecommunications incidents.
/// Persistence and transport concerns are intentionally kept outside this policy.
/// </summary>
public sealed record SupportIncidentReport(
    Guid StationId,
    Guid ReporterUserId,
    SupportIncidentKind Kind,
    string Category,
    string Title,
    string Description,
    string? AffectedAsset,
    SupportIncidentSeverity Severity,
    DateTimeOffset OccurredAt,
    bool ImpactsOperations);

public enum SupportIncidentKind
{
    InformationTechnology,
    Telecommunications
}

public enum SupportIncidentSeverity
{
    Low,
    Normal,
    High,
    Critical
}

public enum SupportIncidentStatus
{
    Submitted,
    UnderReview,
    Assigned,
    InProgress,
    WaitingForInformation,
    Resolved,
    Closed,
    Rejected
}

public static class SupportIncidentPolicy
{
    private static readonly IReadOnlyDictionary<SupportIncidentStatus, SupportIncidentStatus[]> AllowedTransitions =
        new Dictionary<SupportIncidentStatus, SupportIncidentStatus[]>
        {
            [SupportIncidentStatus.Submitted] = [SupportIncidentStatus.UnderReview, SupportIncidentStatus.Rejected],
            [SupportIncidentStatus.UnderReview] = [SupportIncidentStatus.Assigned, SupportIncidentStatus.Rejected],
            [SupportIncidentStatus.Assigned] = [SupportIncidentStatus.InProgress, SupportIncidentStatus.UnderReview],
            [SupportIncidentStatus.InProgress] = [SupportIncidentStatus.WaitingForInformation, SupportIncidentStatus.Resolved, SupportIncidentStatus.Assigned],
            [SupportIncidentStatus.WaitingForInformation] = [SupportIncidentStatus.InProgress, SupportIncidentStatus.Resolved],
            [SupportIncidentStatus.Resolved] = [SupportIncidentStatus.Closed, SupportIncidentStatus.InProgress],
            [SupportIncidentStatus.Closed] = [],
            [SupportIncidentStatus.Rejected] = []
        };

    public static IReadOnlyList<ValidationIssue> Validate(SupportIncidentReport report, DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(report);
        var issues = new List<ValidationIssue>();

        if (report.StationId == Guid.Empty)
            issues.Add(new(nameof(report.StationId), "يجب تحديد محطة صحيحة."));
        if (report.ReporterUserId == Guid.Empty)
            issues.Add(new(nameof(report.ReporterUserId), "هوية المبلّغ مطلوبة."));
        if (!Enum.IsDefined(report.Kind))
            issues.Add(new(nameof(report.Kind), "نوع البلاغ غير معروف."));
        if (!Enum.IsDefined(report.Severity))
            issues.Add(new(nameof(report.Severity), "درجة الأولوية غير معروفة."));

        ValidateText(report.Category, nameof(report.Category), 2, 80, "تصنيف البلاغ", issues);
        ValidateText(report.Title, nameof(report.Title), 5, 160, "عنوان البلاغ", issues);
        ValidateText(report.Description, nameof(report.Description), 10, 5000, "وصف المشكلة", issues);

        if (report.AffectedAsset is { } asset &&
            (string.IsNullOrWhiteSpace(asset) || asset.Trim().Length > 160))
        {
            issues.Add(new(nameof(report.AffectedAsset), "اسم الجهاز أو الخدمة المتأثرة يجب أن يكون غير فارغ وألا يتجاوز 160 محرفاً."));
        }

        if (report.OccurredAt == default || report.OccurredAt > now.AddMinutes(5))
            issues.Add(new(nameof(report.OccurredAt), "وقت حدوث المشكلة غير صالح أو يقع في المستقبل."));

        if (report.ImpactsOperations && report.Severity is SupportIncidentSeverity.Low or SupportIncidentSeverity.Normal)
            issues.Add(new(nameof(report.Severity), "المشكلة المؤثرة على سير العمل يجب أن تكون عالية أو حرجة."));

        return issues;
    }

    public static bool CanTransition(SupportIncidentStatus current, SupportIncidentStatus next)
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
