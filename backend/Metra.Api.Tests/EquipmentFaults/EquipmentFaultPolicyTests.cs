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
    [InlineData(" ", "invalid_equipment_name")]
    [InlineData("A", "invalid_equipment_name")]
    [InlineData("  مقياس الحرارة", "invalid_equipment_name")]
    public void Invalid_equipment_name_is_rejected(string name, string expected)
    {
        var request = ValidSubmission() with { EquipmentName = name };
        Assert.Equal(expected, EquipmentFaultPolicy.ValidateSubmission(request, Now));
    }

    [Theory]
    [InlineData("قصير", "invalid_description")]
    [InlineData("", "invalid_description")]
    [InlineData("توقف الجهاز عن إرسال القراءات. ", "invalid_description")]
    public void Invalid_description_is_rejected(string description, string expected)
    {
        var request = ValidSubmission() with { Description = description };
        Assert.Equal(expected, EquipmentFaultPolicy.ValidateSubmission(request, Now));
    }

    [Fact]
    public void Maximum_allowed_field_lengths_are_accepted()
    {
        var request = ValidSubmission() with
        {
            EquipmentCategory = new string('ج', 80),
            EquipmentName = new string('م', 120),
            Description = new string('و', 4000)
        };
        Assert.Null(EquipmentFaultPolicy.ValidateSubmission(request, Now));
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

    [Theory]
    [InlineData((EquipmentFaultStatus)999, EquipmentFaultStatus.UnderReview)]
    [InlineData(EquipmentFaultStatus.Submitted, (EquipmentFaultStatus)999)]
    public void Undefined_status_values_never_produce_a_transition_permission(
        EquipmentFaultStatus from, EquipmentFaultStatus to)
    {
        Assert.False(EquipmentFaultPolicy.TryGetRequiredPermission(from, to, out _));
        Assert.False(EquipmentFaultPolicy.CanTransition(
            from, to, new HashSet<string>
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

    [Fact]
    public void Transition_matrix_allows_only_explicitly_declared_edges()
    {
        var expected = new Dictionary<(EquipmentFaultStatus From, EquipmentFaultStatus To), string>
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

        var statuses = Enum.GetValues<EquipmentFaultStatus>();
        foreach (var from in statuses)
        foreach (var to in statuses)
        {
            var allowed = EquipmentFaultPolicy.TryGetRequiredPermission(from, to, out var actual);
            var expectedAllowed = expected.TryGetValue((from, to), out var permission);
            Assert.Equal(expectedAllowed, allowed);
            if (expectedAllowed)
                Assert.Equal(permission, actual);
        }
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
