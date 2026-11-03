using Metra.Api.Domain.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class RegistrationApprovalAuthorizationPolicyTests
{
    [Fact]
    public void Station_decision_requires_matching_station_assignment()
    {
        var actor = new RegistrationApprovalActorContext(
            "reviewer", true, true, new HashSet<string> { "station-a" }, false);
        var request = new RegistrationApprovalRequestContext(
            "request", "applicant", "station-b",
            RegistrationApprovalStatus.PendingStationApproval);

        var result = RegistrationApprovalAuthorizationPolicy.Authorize(actor, request);

        Assert.False(result.IsAuthorized);
        Assert.Equal("station_scope_violation", result.ErrorCode);
    }


    [Fact]
    public void Station_assignment_alone_does_not_grant_station_approval_permission()
    {
        var actor = new RegistrationApprovalActorContext(
            "reviewer", true, false, new HashSet<string> { "station-a" }, false);
        var request = new RegistrationApprovalRequestContext(
            "request", "applicant", "station-a",
            RegistrationApprovalStatus.PendingStationApproval);

        var result = RegistrationApprovalAuthorizationPolicy.Authorize(actor, request);

        Assert.False(result.IsAuthorized);
        Assert.Equal("station_approval_permission_required", result.ErrorCode);
    }

    [Theory]
    [InlineData(null, "station-a")]
    [InlineData("", "station-a")]
    [InlineData("applicant", null)]
    [InlineData("applicant", " ")]
    public void Incomplete_request_identity_or_station_scope_fails_closed(
        string? requestedByUserId,
        string? requestedStationId)
    {
        var actor = new RegistrationApprovalActorContext(
            "reviewer", true, true, new HashSet<string> { "station-a" }, true);
        var request = new RegistrationApprovalRequestContext(
            "request", requestedByUserId!, requestedStationId!,
            RegistrationApprovalStatus.PendingStationApproval);

        var result = RegistrationApprovalAuthorizationPolicy.Authorize(actor, request);

        Assert.False(result.IsAuthorized);
        Assert.Equal("registration_request_invalid", result.ErrorCode);
    }

    [Fact]
    public void Final_decision_requires_persisted_station_approval_evidence()
    {
        var actor = new RegistrationApprovalActorContext(
            "system-reviewer", true, false, new HashSet<string>(), true);
        var request = new RegistrationApprovalRequestContext(
            "request", "applicant", "station-a",
            RegistrationApprovalStatus.PendingSystemApproval);

        var result = RegistrationApprovalAuthorizationPolicy.Authorize(actor, request);

        Assert.False(result.IsAuthorized);
        Assert.Equal("station_approval_evidence_missing", result.ErrorCode);
    }

    [Fact]
    public void Station_reviewer_cannot_also_complete_system_approval()
    {
        var actor = new RegistrationApprovalActorContext(
            "same-reviewer", true, false, new HashSet<string>(), true);
        var request = new RegistrationApprovalRequestContext(
            "request", "applicant", "station-a",
            RegistrationApprovalStatus.PendingSystemApproval, "same-reviewer");

        var result = RegistrationApprovalAuthorizationPolicy.Authorize(actor, request);

        Assert.False(result.IsAuthorized);
        Assert.Equal("approval_separation_of_duties_violation", result.ErrorCode);
    }

    [Fact]
    public void Final_decision_requires_explicit_system_permission()
    {
        var actor = new RegistrationApprovalActorContext(
            "reviewer", true, false, new HashSet<string>(), false);
        var request = new RegistrationApprovalRequestContext(
            "request", "applicant", "station-a",
            RegistrationApprovalStatus.PendingSystemApproval, "station-reviewer");

        var result = RegistrationApprovalAuthorizationPolicy.Authorize(actor, request);

        Assert.False(result.IsAuthorized);
        Assert.Equal("system_approval_permission_required", result.ErrorCode);
    }

    [Fact]
    public void Final_decision_is_allowed_for_system_approver()
    {
        var actor = new RegistrationApprovalActorContext(
            "reviewer", true, false, new HashSet<string>(), true);
        var request = new RegistrationApprovalRequestContext(
            "request", "applicant", "station-a",
            RegistrationApprovalStatus.PendingSystemApproval, "station-reviewer");

        var result = RegistrationApprovalAuthorizationPolicy.Authorize(actor, request);

        Assert.True(result.IsAuthorized);
    }
}
