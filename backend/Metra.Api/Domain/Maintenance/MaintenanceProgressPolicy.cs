using Metra.Api.Domain.Observations;

namespace Metra.Api.Domain.Maintenance;

/// <summary>Validates workshop progress updates independently of persistence and authorization.</summary>
public sealed record MaintenanceProgressUpdate(
    Guid FaultId,
    Guid StationId,
    EquipmentFaultStatus Status,
    int ProgressPercent,
    DateTimeOffset UpdatedAt,
    string? ProgressNote);

public static class MaintenanceProgressPolicy
{
    public static IReadOnlyList<ValidationIssue> Validate(
        MaintenanceProgressUpdate update,
        DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(update);
        var issues = new List<ValidationIssue>();

        if (update.FaultId == Guid.Empty)
            issues.Add(new(nameof(update.FaultId), "يجب تحديد بلاغ العطل."));
        if (update.StationId == Guid.Empty)
            issues.Add(new(nameof(update.StationId), "يجب تحديد المحطة."));
        if (!Enum.IsDefined(update.Status))
            issues.Add(new(nameof(update.Status), "حالة العطل غير معروفة."));
        if (update.ProgressPercent is < 0 or > 100)
            issues.Add(new(nameof(update.ProgressPercent), "نسبة الإنجاز يجب أن تكون بين 0 و100."));
        if (update.UpdatedAt == default || update.UpdatedAt > now.AddMinutes(5))
            issues.Add(new(nameof(update.UpdatedAt), "وقت تحديث الإنجاز غير صالح."));
        if (update.ProgressNote?.Length > 1000)
            issues.Add(new(nameof(update.ProgressNote), "ملاحظة الإنجاز يجب ألا تتجاوز 1000 محرف."));

        if (update.Status == EquipmentFaultStatus.Resolved && update.ProgressPercent != 100)
            issues.Add(new(nameof(update.ProgressPercent), "لا يمكن تسجيل العطل محلولاً قبل اكتمال الإنجاز بنسبة 100."));
        if (update.Status is EquipmentFaultStatus.Closed or EquipmentFaultStatus.Rejected)
            issues.Add(new(nameof(update.Status), "لا يمكن تحديث تقدم عطل مغلق أو مرفوض."));

        return issues;
    }
}
