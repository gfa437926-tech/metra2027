using Metra.Api.Domain.Maintenance;
using Xunit;

namespace Metra.Api.Tests.Domain;

public sealed class MaintenanceProgressPolicyTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 5, 8, 0, 0, TimeSpan.Zero);

    private static MaintenanceProgressUpdate Valid() => new(
        Guid.NewGuid(), Guid.NewGuid(), EquipmentFaultStatus.Assigned, EquipmentFaultStatus.InProgress, 45,
        Now, "تم فحص الجهاز وبدء المعايرة");

    [Fact]
    public void Accepts_valid_progress_update() =>
        Assert.Empty(MaintenanceProgressPolicy.Validate(Valid(), Now));

    [Fact]
    public void Requires_fault_and_station_identifiers()
    {
        var update = Valid() with { FaultId = Guid.Empty, StationId = Guid.Empty };
        var issues = MaintenanceProgressPolicy.Validate(update, Now);
        Assert.Contains(issues, x => x.Field == nameof(update.FaultId));
        Assert.Contains(issues, x => x.Field == nameof(update.StationId));
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(101)]
    public void Rejects_progress_outside_zero_to_one_hundred(int percent)
    {
        var update = Valid() with { ProgressPercent = percent };
        Assert.Contains(MaintenanceProgressPolicy.Validate(update, Now),
            x => x.Field == nameof(update.ProgressPercent));
    }

    [Fact]
    public void Resolved_fault_requires_full_progress()
    {
        var update = Valid() with { Status = EquipmentFaultStatus.Resolved, ProgressPercent = 99 };
        Assert.Contains(MaintenanceProgressPolicy.Validate(update, Now),
            x => x.Field == nameof(update.ProgressPercent));
    }

    [Fact]
    public void Accepts_resolved_fault_at_full_progress()
    {
        var update = Valid() with { Status = EquipmentFaultStatus.Resolved, ProgressPercent = 100 };
        Assert.Empty(MaintenanceProgressPolicy.Validate(update, Now));
    }

    [Theory]
    [InlineData(EquipmentFaultStatus.Closed)]
    [InlineData(EquipmentFaultStatus.Rejected)]
    public void Rejects_progress_updates_for_terminal_faults(EquipmentFaultStatus status)
    {
        var update = Valid() with { Status = status };
        Assert.Contains(MaintenanceProgressPolicy.Validate(update, Now),
            x => x.Field == nameof(update.Status));
    }

    [Fact]
    public void Rejects_progress_note_over_limit()
    {
        var update = Valid() with { ProgressNote = new string('x', 1001) };
        Assert.Contains(MaintenanceProgressPolicy.Validate(update, Now),
            x => x.Field == nameof(update.ProgressNote));
    }

    [Fact]
    public void Rejects_update_time_too_far_in_future()
    {
        var update = Valid() with { UpdatedAt = Now.AddMinutes(6) };
        Assert.Contains(MaintenanceProgressPolicy.Validate(update, Now),
            x => x.Field == nameof(update.UpdatedAt));
    }

    [Fact]
    public void Accepts_progress_note_at_exact_limit()
    {
        var update = Valid() with { ProgressNote = new string('x', 1000) };
        Assert.Empty(MaintenanceProgressPolicy.Validate(update, Now));
    }

    [Fact]
    public void Rejects_null_update() =>
        Assert.Throws<ArgumentNullException>(() =>
            MaintenanceProgressPolicy.Validate(null!, Now));
}

    [Theory]
    [InlineData(EquipmentFaultStatus.Submitted, EquipmentFaultStatus.InProgress)]
    [InlineData(EquipmentFaultStatus.Assigned, EquipmentFaultStatus.Closed)]
    [InlineData(EquipmentFaultStatus.Closed, EquipmentFaultStatus.InProgress)]
    [InlineData(EquipmentFaultStatus.Rejected, EquipmentFaultStatus.Assigned)]
    public void Rejects_invalid_lifecycle_transition(
        EquipmentFaultStatus current,
        EquipmentFaultStatus next)
    {
        var update = Valid() with { CurrentStatus = current, Status = next };
        Assert.Contains(MaintenanceProgressPolicy.Validate(update, Now),
            x => x.Field == nameof(update.Status));
    }

    [Fact]
    public void Accepts_allowed_lifecycle_transition()
    {
        var update = Valid() with
        {
            CurrentStatus = EquipmentFaultStatus.Assigned,
            Status = EquipmentFaultStatus.InProgress
        };
        Assert.Empty(MaintenanceProgressPolicy.Validate(update, Now));
        [Fact]
    public void Rejects_unknown_current_status()
    {
        var update = Valid() with { CurrentStatus = (EquipmentFaultStatus)999 };
        Assert.Contains(MaintenanceProgressPolicy.Validate(update, Now),
            x => x.Field == nameof(update.CurrentStatus));
    }

}
