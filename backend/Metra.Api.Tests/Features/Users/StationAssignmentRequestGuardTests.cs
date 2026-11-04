using Metra.Api.Features.Users;
using Xunit;

namespace Metra.Api.Tests.Features.Users;

public sealed class StationAssignmentRequestGuardTests
{
    private static readonly Guid Actor = Guid.Parse("11111111-1111-4111-8111-111111111111");
    private static readonly Guid Target = Guid.Parse("22222222-2222-4222-8222-222222222222");
    private static StationAssignmentRequest Valid() => new(
        Target, "observer", "احتياج تشغيلي موثق",
        DateTimeOffset.Parse("2026-11-04T08:00:00Z"), null);

    [Fact]
    public void Accepts_only_a_different_target_with_limited_station_role()
    {
        Assert.Null(StationAssignmentRequestGuard.GetError(Valid(), Actor));
    }

    [Fact]
    public void Rejects_self_assignment_and_manager_roles()
    {
        Assert.Equal("invalid_assignment_target",
            StationAssignmentRequestGuard.GetError(Valid() with { UserId = Actor }, Actor));
        Assert.Equal("station_role_not_assignable",
            StationAssignmentRequestGuard.GetError(Valid() with { RoleCode = "system_admin" }, Actor));
        Assert.Equal("station_role_not_assignable",
            StationAssignmentRequestGuard.GetError(Valid() with { RoleCode = null }, Actor));
    }

    [Fact]
    public void Rejects_invalid_reason_and_date_range()
    {
        Assert.Equal("invalid_assignment_reason",
            StationAssignmentRequestGuard.GetError(Valid() with { Reason = "قصير" }, Actor));
        Assert.Equal("invalid_assignment_validity",
            StationAssignmentRequestGuard.GetError(Valid() with {
                ValidTo = DateTimeOffset.Parse("2026-11-03T08:00:00Z")
            }, Actor));
    }
}

public sealed class StationAssignmentDecisionRequestGuardTests
{
    [Theory]
    [InlineData("approve", null, null)]
    [InlineData("reject", "سبب الرفض واضح", null)]
    [InlineData("reject", null, "assignment_rejection_reason_required")]
    [InlineData("delete", "سبب واضح", "invalid_assignment_decision")]
    [InlineData("approve", " padded ", "invalid_assignment_note")]
    public void Validates_assignment_decision(string? decision, string? note, string? expected)
    {
        Assert.Equal(expected, StationAssignmentDecisionRequestGuard.GetError(
            decision is null && note is null
                ? null
                : new StationAssignmentDecisionRequest(decision, note)));
    }
}
