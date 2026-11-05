using Metra.Api.Domain.Observations;

namespace Metra.Api.Domain.Maintenance;

/// <summary>Rules for assigning and tracking workshop maintenance work without persistence assumptions.</summary>
public sealed record MaintenanceAssignment(
    Guid FaultId,
    Guid StationId,
    Guid AssignedUserId,
    DateTimeOffset AssignedAt,
    DateTimeOffset? ExpectedResolutionAt,
    string? AssignmentNote);

public static class MaintenanceAssignmentPolicy
{
    public static IReadOnlyList<ValidationIssue> Validate(
        MaintenanceAssignment assignment,
        DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(assignment);
        var issues = new List<ValidationIssue>();
        if (assignment.FaultId == Guid.Empty)
            issues.Add(new(nameof(assignment.FaultId), "يجب تحديد بلاغ عطل صحيح."));
        if (assignment.StationId == Guid.Empty)
            issues.Add(new(nameof(assignment.StationId), "يجب تحديد المحطة."));
        if (assignment.AssignedUserId == Guid.Empty)
            issues.Add(new(nameof(assignment.AssignedUserId), "يجب تحديد الفني المسؤول."));
        if (assignment.AssignedAt == default || assignment.AssignedAt > now.AddMinutes(5))
            issues.Add(new(nameof(assignment.AssignedAt), "وقت الإسناد غير صالح."));
        if (assignment.ExpectedResolutionAt is { } expected &&
            (expected <= assignment.AssignedAt || expected > now.AddDays(365)))
            issues.Add(new(nameof(assignment.ExpectedResolutionAt), "موعد الإنجاز المتوقع يجب أن يكون بعد الإسناد وخلال سنة."));
        if (assignment.AssignmentNote?.Length > 1000)
            issues.Add(new(nameof(assignment.AssignmentNote), "ملاحظات الإسناد يجب ألا تتجاوز 1000 محرف."));
        return issues;
    }
}
