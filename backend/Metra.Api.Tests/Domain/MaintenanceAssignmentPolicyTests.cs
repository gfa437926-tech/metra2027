using Metra.Api.Domain.Maintenance;
using Xunit;

namespace Metra.Api.Tests.Domain;

public sealed class MaintenanceAssignmentPolicyTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 5, 8, 0, 0, TimeSpan.Zero);
    private static MaintenanceAssignment Valid() => new(
        Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Now.AddMinutes(-2),
        Now.AddDays(2), "فحص الجهاز وإعادة معايرته");

    [Fact]
    public void Accepts_valid_assignment() =>
        Assert.Empty(MaintenanceAssignmentPolicy.Validate(Valid(), Now));

    [Fact]
    public void Requires_fault_station_and_assignee() {
        var assignment = Valid() with { FaultId = Guid.Empty, StationId = Guid.Empty, AssignedUserId = Guid.Empty };
        var issues = MaintenanceAssignmentPolicy.Validate(assignment, Now);
        Assert.Contains(issues, x => x.Field == nameof(assignment.FaultId));
        Assert.Contains(issues, x => x.Field == nameof(assignment.StationId));
        Assert.Contains(issues, x => x.Field == nameof(assignment.AssignedUserId));
    }

    [Fact]
    public void Expected_resolution_must_follow_assignment() {
        var assignment = Valid() with { ExpectedResolutionAt = Now.AddMinutes(-3) };
        Assert.Contains(MaintenanceAssignmentPolicy.Validate(assignment, Now),
            x => x.Field == nameof(assignment.ExpectedResolutionAt));
    }

    [Fact]
    public void Rejects_assignment_note_over_limit() {
        var assignment = Valid() with { AssignmentNote = new string('x', 1001) };
        Assert.Contains(MaintenanceAssignmentPolicy.Validate(assignment, Now),
            x => x.Field == nameof(assignment.AssignmentNote));
    }
}
