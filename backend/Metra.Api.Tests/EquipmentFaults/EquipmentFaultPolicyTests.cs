using Metra.Api.Features.EquipmentFaults;

namespace Metra.Api.Tests.EquipmentFaults;

public sealed class EquipmentFaultPolicyTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 7, 12, 0, 0, TimeSpan.Zero);

    private static EquipmentFaultSubmission ValidSubmission(
        EquipmentFaultSeverity severity = EquipmentFaultSeverity.High,
        bool blocking = false,
        DateTimeOffset? occurredAt = null) =>
        new("أجهزة الرصد", "مقياس الحرارة", "توقف الجهاز عن إرسال القراءات.", severity,
            occurredAt ?? Now, blocking);

    [Fact]
    public void Valid_submission_is_accepted()
    {
        Assert.Null(EquipmentFaultPolicy.ValidateSubmission(ValidSubmission(), Now));
    }

    [Theory]
    [InlineData(null, "invalid_equipment_category")]
    [InlineData("", "invalid_equipment_category")]
    [InlineData("A", "invalid_equipment_category")]
    public void Invalid_category_is_rejected(string? category, string expected)
    {
        var request = ValidSubmission() with { EquipmentCategory = category };
        Assert.Equal(expected, EquipmentFaultPolicy.ValidateSubmission(request, Now));
    }

    [Fact]
    public void Undefined_severity_value_is_rejected()
    {
        var request = ValidSubmission() with { Severity = (EquipmentFaultSeverity)999 };
        Assert.Equal("invalid_severity", EquipmentFaultPolicy.ValidateSubmission(request, Now));
    }

    [Fact]
    public void Missing_permission_set_never_authorizes_a_transition()
    {
        Assert.False(EquipmentFaultPolicy.CanTransition(
            EquipmentFaultStatus.UnderReview,
            EquipmentFaultStatus.Assigned,
            null!));
    }

    [Theory]
    [InlineData(EquipmentFaultSeverity.Low)]
    [InlineData(EquipmentFaultSeverity.Medium)]
    public void Operationally_blocking_fault_requires_high_or_critical_severity(
        EquipmentFaultSeverity severity)
    {
        Assert.Equal(
            "blocking_fault_requires_high_severity",
            EquipmentFaultPolicy.ValidateSubmission(
                ValidSubmission(severity, blocking: true), Now));
    }

    [Fact]
    public void Occurrence_time_more_than_five_minutes_in_future_is_rejected()
    {
        var request = ValidSubmission(occurredAt: Now.AddMinutes(6));
        Assert.Equal("invalid_occurred_at", EquipmentFaultPolicy.ValidateSubmission(request, Now));
    }

    [Fact]
    public void Occurrence_time_exactly_five_minutes_in_future_is_accepted()
    {
        var request = ValidSubmission(occurredAt: Now.AddMinutes(5));
        Assert.Null(EquipmentFaultPolicy.ValidateSubmission(request, Now));
    }

    [Theory]
    [InlineData(EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview, "equipment_fault.review")]
    [InlineData(EquipmentFaultStatus.Submitted, EquipmentFaultStatus.Rejected, "equipment_fault.review")]
    [InlineData(EquipmentFaultStatus.UnderReview, EquipmentFaultStatus.Assigned, "equipment_fault.assign")]
    [InlineData(EquipmentFaultStatus.UnderReview, EquipmentFaultStatus.Rejected, "equipment_fault.review")]
    [InlineData(EquipmentFaultStatus.Assigned, EquipmentFaultStatus.UnderReview, "equipment_fault.review")]
    [InlineData(EquipmentFaultStatus.Assigned, EquipmentFaultStatus.InProgress, "equipment_fault.resolve")]
    [InlineData(EquipmentFaultStatus.InProgress, EquipmentFaultStatus.Resolved, "equipment_fault.resolve")]
    [InlineData(EquipmentFaultStatus.Resolved, EquipmentFaultStatus.InProgress, "equipment_fault.resolve")]
    [InlineData(EquipmentFaultStatus.Resolved, EquipmentFaultStatus.Closed, "equipment_fault.close")]
    public void Allowed_transitions_return_the_required_permission(
        EquipmentFaultStatus from, EquipmentFaultStatus to, string permission)
    {
        Assert.True(EquipmentFaultPolicy.TryGetRequiredPermission(from, to, out var actual));
        Assert.Equal(permission, actual);
    }

    [Theory]
    [InlineData(EquipmentFaultStatus.Submitted, EquipmentFaultStatus.Closed)]
    [InlineData(EquipmentFaultStatus.Closed, EquipmentFaultStatus.InProgress)]
    [InlineData(EquipmentFaultStatus.Rejected, EquipmentFaultStatus.UnderReview)]
    [InlineData(EquipmentFaultStatus.InProgress, EquipmentFaultStatus.Closed)]
    public void Disallowed_transitions_are_rejected(
        EquipmentFaultStatus from, EquipmentFaultStatus to)
    {
        Assert.False(EquipmentFaultPolicy.TryGetRequiredPermission(from, to, out _));
        Assert.False(EquipmentFaultPolicy.CanTransition(from, to, new HashSet<string>
        {
            "equipment_fault.review",
            "equipment_fault.assign",
            "equipment_fault.resolve",
            "equipment_fault.close"
        }));
    }

    [Fact]
    public void Transition_requires_its_specific_permission()
    {
        Assert.False(EquipmentFaultPolicy.CanTransition(
            EquipmentFaultStatus.UnderReview,
            EquipmentFaultStatus.Assigned,
            new HashSet<string> { "equipment_fault.review" }));

        Assert.True(EquipmentFaultPolicy.CanTransition(
            EquipmentFaultStatus.UnderReview,
            EquipmentFaultStatus.Assigned,
            new HashSet<string> { "equipment_fault.assign" }));
    }

    [Theory]
    [InlineData(EquipmentFaultStatus.Closed)]
    [InlineData(EquipmentFaultStatus.Rejected)]
    public void Closed_and_rejected_are_terminal(EquipmentFaultStatus status)
    {
        Assert.True(EquipmentFaultPolicy.IsTerminal(status));
    }

    [Theory]
    [InlineData(EquipmentFaultStatus.Submitted)]
    [InlineData(EquipmentFaultStatus.UnderReview)]
    [InlineData(EquipmentFaultStatus.Assigned)]
    [InlineData(EquipmentFaultStatus.InProgress)]
    [InlineData(EquipmentFaultStatus.Resolved)]
    public void Non_terminal_statuses_are_not_terminal(EquipmentFaultStatus status)
    {
        Assert.False(EquipmentFaultPolicy.IsTerminal(status));
    }
}
