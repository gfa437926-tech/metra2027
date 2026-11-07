namespace Metra.Api.Features.EquipmentFaults;

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

public enum EquipmentFaultSeverity
{
    Low,
    Medium,
    High,
    Critical
}

public sealed record EquipmentFaultSubmission(
    string? EquipmentCategory,
    string? EquipmentName,
    string? Description,
    EquipmentFaultSeverity Severity,
    DateTimeOffset? OccurredAt,
    bool IsOperationallyBlocking);

public sealed record EquipmentFaultTransition(
    EquipmentFaultStatus From,
    EquipmentFaultStatus To,
    string RequiredPermission);

public sealed record EquipmentFaultAuditEntry(
    Guid FaultId,
    Guid ActorId,
    DateTimeOffset OccurredAt,
    EquipmentFaultStatus? PreviousStatus,
    EquipmentFaultStatus NewStatus,
    string Reason);

/// <summary>
/// Pure domain policy. It deliberately has no persistence or HTTP dependencies.
/// Callers must independently establish identity, permission, and station scope.
/// </summary>
public static class EquipmentFaultPolicy
{
    private static readonly IReadOnlyDictionary<(EquipmentFaultStatus From, EquipmentFaultStatus To), string>
        AllowedTransitions = new Dictionary<(EquipmentFaultStatus, EquipmentFaultStatus), string>
        {
            [(EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview)] = "equipment_fault.review",
            [(EquipmentFaultStatus.Submitted, EquipmentFaultStatus.Rejected)] = "equipment_fault.review",
            [(EquipmentFaultStatus.UnderReview, EquipmentFaultStatus.Assigned)] = "equipment_fault.assign",
            [(EquipmentFaultStatus.UnderReview, EquipmentFaultStatus.Rejected)] = "equipment_fault.review",
            [(EquipmentFaultStatus.Assigned, EquipmentFaultStatus.UnderReview)] = "equipment_fault.review",
            [(EquipmentFaultStatus.Assigned, EquipmentFaultStatus.InProgress)] = "equipment_fault.resolve",
            [(EquipmentFaultStatus.InProgress, EquipmentFaultStatus.Resolved)] = "equipment_fault.resolve",
            [(EquipmentFaultStatus.Resolved, EquipmentFaultStatus.InProgress)] = "equipment_fault.resolve",
            [(EquipmentFaultStatus.Resolved, EquipmentFaultStatus.Closed)] = "equipment_fault.close"
        };

    public static string? ValidateSubmission(EquipmentFaultSubmission? submission, DateTimeOffset now)
    {
        if (submission is null)
            return "invalid_request";

        if (!HasLength(submission.EquipmentCategory, 2, 80))
            return "invalid_equipment_category";

        if (!HasLength(submission.EquipmentName, 2, 120))
            return "invalid_equipment_name";

        if (!HasLength(submission.Description, 10, 4000))
            return "invalid_description";

        if (!Enum.IsDefined(submission.Severity))
            return "invalid_severity";

        if (submission.OccurredAt is null || submission.OccurredAt > now.AddMinutes(5))
            return "invalid_occurred_at";

        if (submission.IsOperationallyBlocking &&
            submission.Severity is not (EquipmentFaultSeverity.High or EquipmentFaultSeverity.Critical))
            return "blocking_fault_requires_high_severity";

        return null;
    }

    public static bool TryGetRequiredPermission(
        EquipmentFaultStatus from,
        EquipmentFaultStatus to,
        out string requiredPermission) =>
        AllowedTransitions.TryGetValue((from, to), out requiredPermission!);

    public static bool CanTransition(
        EquipmentFaultStatus from,
        EquipmentFaultStatus to,
        IReadOnlySet<string>? permissions) =>
        permissions is not null &&
        AllowedTransitions.TryGetValue((from, to), out var required) &&
        permissions.Contains(required);

    public static bool IsTerminal(EquipmentFaultStatus status) =>
        status is EquipmentFaultStatus.Closed or EquipmentFaultStatus.Rejected;

    private static bool HasLength(string? value, int min, int max) =>
        value is not null &&
        value == value.Trim() &&
        value.Length >= min &&
        value.Length <= max;
}
