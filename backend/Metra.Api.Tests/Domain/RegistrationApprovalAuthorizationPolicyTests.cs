using Metra.Api.Domain.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class RegistrationApprovalAuthorizationPolicyTests
{
    [Fact]
    public void Station_decision_requires_matching_station_assignment()
    {
        var actor = new RegistrationApprovalActorContext(
            "reviewer", true, new HashSet<string> { "station-a" }, false);
        var request = new RegistrationApprovalRequestContext(
            "request", "applicant", "station-b",
            RegistrationApprovalStatus.PendingStationApproval);

        var result = RegistrationApprovalAuthorizationPolicy.Authorize(actor, request);

        Assert.False(result.IsAuthorized);
        Assert.Equal("station_scope_violation", result.ErrorCode);
    }

    [Fact]
    public void Final_decision_requires_explicit_system_permission()
    {
        var actor = new RegistrationApprovalActorContext(
            "reviewer", true, new HashSet<string>(), false);
        var request = new RegistrationApprovalRequestContext(
            "request", "applicant", "station-a",
            RegistrationApprovalStatus.PendingSystemApproval);

        var result = RegistrationApprovalAuthorizationPolicy.Authorize(actor, request);

        Assert.False(result.IsAuthorized);
        Assert.Equal("system_approval_permission_required", result.ErrorCode);
    }

    [Fact]
    public void Final_decision_is_allowed_for_system_approver()
    {
        var actor = new RegistrationApprovalActorContext(
            "reviewer", true, new HashSet<string>(), true);
        var request = new RegistrationApprovalRequestContext(
            "request", "applicant", "station-a",
            RegistrationApprovalStatus.PendingSystemApproval);

        var result = RegistrationApprovalAuthorizationPolicy.Authorize(actor, request);

        Assert.True(result.IsAuthorized);
    }
}
