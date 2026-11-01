using Metra.Api.Domain.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class RegistrationApprovalWorkflowTests
{
    [Theory]
    [InlineData(RegistrationApprovalStatus.PendingStationApproval, RegistrationApprovalDecision.Approve, RegistrationApprovalStatus.PendingSystemApproval, RegistrationApprovalStage.Station)]
    [InlineData(RegistrationApprovalStatus.PendingStationApproval, RegistrationApprovalDecision.Reject, RegistrationApprovalStatus.Rejected, RegistrationApprovalStage.Station)]
    [InlineData(RegistrationApprovalStatus.PendingSystemApproval, RegistrationApprovalDecision.Approve, RegistrationApprovalStatus.Active, RegistrationApprovalStage.System)]
    [InlineData(RegistrationApprovalStatus.PendingSystemApproval, RegistrationApprovalDecision.Reject, RegistrationApprovalStatus.Rejected, RegistrationApprovalStage.System)]
    public void Applies_allowed_stage_decisions(
        RegistrationApprovalStatus current,
        RegistrationApprovalDecision decision,
        RegistrationApprovalStatus expected,
        RegistrationApprovalStage expectedStage)
    {
        var result = RegistrationApprovalWorkflow.Apply(current, decision);

        Assert.True(result.Succeeded);
        Assert.Equal(expected, result.Status);
        Assert.Equal(expectedStage, result.Transition?.Stage);
        Assert.Equal(current, result.Transition?.From);
        Assert.Equal(decision, result.Transition?.Decision);
        Assert.Null(result.Issue);
    }

    [Theory]
    [InlineData(RegistrationApprovalStatus.Active, RegistrationApprovalDecision.Approve)]
    [InlineData(RegistrationApprovalStatus.Active, RegistrationApprovalDecision.Reject)]
    [InlineData(RegistrationApprovalStatus.Rejected, RegistrationApprovalDecision.Approve)]
    [InlineData(RegistrationApprovalStatus.Rejected, RegistrationApprovalDecision.Reject)]
    public void Rejects_decisions_for_terminal_requests(
        RegistrationApprovalStatus current,
        RegistrationApprovalDecision decision)
    {
        var result = RegistrationApprovalWorkflow.Apply(current, decision);

        Assert.False(result.Succeeded);
        Assert.Equal(current, result.Status);
        Assert.Null(result.Transition);
        Assert.Equal("invalid_transition", result.Issue?.Code);
    }
}
