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
    public void Requires_fault_station_and_assignee()
    {
        var assignment = Valid() with
        {
            FaultId = Guid.Empty,
            StationId = Guid.Empty,
            AssignedUserId = Guid.Empty
        };
        var issues = MaintenanceAssignmentPolicy.Validate(assignment, Now);
        Assert.Contains(issues, x => x.Field == nameof(assignment.FaultId));
        Assert.Contains(issues, x => x.Field == nameof(assignment.StationId));
        Assert.Contains(issues, x => x.Field == nameof(assignment.AssignedUserId));
    }

    [Fact]
    public void Expected_resolution_must_follow_assignment()
    {
        var assignment = Valid() with { ExpectedResolutionAt = Now.AddMinutes(-3) };
        Assert.Contains(MaintenanceAssignmentPolicy.Validate(assignment, Now),
            x => x.Field == nameof(assignment.ExpectedResolutionAt));
    }

    [Fact]
    public void Rejects_assignment_note_over_limit()
    {
        var assignment = Valid() with { AssignmentNote = new string('x', 1001) };
        Assert.Contains(MaintenanceAssignmentPolicy.Validate(assignment, Now),
            x => x.Field == nameof(assignment.AssignmentNote));
    }

    [Fact]
    public void Rejects_assignment_time_too_far_in_future()
    {
        var assignment = Valid() with { AssignedAt = Now.AddMinutes(6) };
        Assert.Contains(MaintenanceAssignmentPolicy.Validate(assignment, Now),
            x => x.Field == nameof(assignment.AssignedAt));
    }

    [Fact]
    public void Rejects_expected_resolution_beyond_one_year()
    {
        var assignment = Valid() with { ExpectedResolutionAt = Now.AddDays(366) };
        Assert.Contains(MaintenanceAssignmentPolicy.Validate(assignment, Now),
            x => x.Field == nameof(assignment.ExpectedResolutionAt));
    }

    [Fact]
    public void Allows_optional_assignment_note_to_be_null()
    {
        var assignment = Valid() with { AssignmentNote = null };
        Assert.Empty(MaintenanceAssignmentPolicy.Validate(assignment, Now));
    }

    [Fact]
    public void Accepts_assignment_at_five_minute_future_boundary() =>
        Assert.Empty(MaintenanceAssignmentPolicy.Validate(
            Valid() with { AssignedAt = Now.AddMinutes(5) }, Now));

    [Fact]
    public void Accepts_expected_resolution_at_one_year_boundary() =>
        Assert.Empty(MaintenanceAssignmentPolicy.Validate(
            Valid() with { ExpectedResolutionAt = Now.AddDays(365) }, Now));

    [Theory]
    [InlineData("   ")]
    [InlineData("\t\n")]
    public void Rejects_blank_assignment_note(string note)
    {
        var assignment = Valid() with { AssignmentNote = note };
        Assert.Contains(MaintenanceAssignmentPolicy.Validate(assignment, Now),
            x => x.Field == nameof(assignment.AssignmentNote));
    }

    [Fact]
    public void Accepts_assignment_note_at_exact_limit() =>
        Assert.Empty(MaintenanceAssignmentPolicy.Validate(
            Valid() with { AssignmentNote = new string('x', 1000) }, Now));

    [Fact]
    public void Rejects_default_assignment_timestamp() =>
        Assert.Contains(MaintenanceAssignmentPolicy.Validate(
            Valid() with { AssignedAt = default }, Now),
            x => x.Field == nameof(MaintenanceAssignment.AssignedAt));

    [Fact]
    public void Rejects_null_assignment() =>
        Assert.Throws<ArgumentNullException>(() =>
            MaintenanceAssignmentPolicy.Validate(null!, Now));
}
