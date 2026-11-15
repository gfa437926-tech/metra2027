using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class MetraStationReadAuthorizationTests
{
    private static readonly Guid StationA = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static readonly Guid StationB = Guid.Parse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");

    [Fact]
    public void Ordinary_station_user_can_read_only_the_assigned_station()
    {
        var actor = Actor(Grant("observer", "station", StationA, "observations.read_station"));

        var ownStation = MetraStationReadAuthorization.Evaluate(actor, StationA, "observations.read_station");
        var otherStation = MetraStationReadAuthorization.Evaluate(actor, StationB, "observations.read_station");

        Assert.True(ownStation.Allowed);
        Assert.Equal(MetraAuthorizationOutcome.AllowedStationScope, ownStation.Outcome);
        Assert.False(otherStation.Allowed);
    }

    [Theory]
    [InlineData("auditor")]
    [InlineData("network_department_head")]
    public void Approved_global_read_roles_can_read_any_station_with_explicit_global_permission(string role)
    {
        var actor = Actor(Grant(role, "global_read", null, "stations.read_all"));

        var decision = MetraStationReadAuthorization.Evaluate(actor, StationB, "stations.read_all");

        Assert.True(decision.Allowed);
        Assert.Equal(MetraAuthorizationOutcome.AllowedGlobalRead, decision.Outcome);
    }

    [Fact]
    public void Station_role_cannot_obtain_global_access_by_claiming_global_scope()
    {
        var actor = Actor(Grant("observer", "global_read", null, "stations.read_all"));

        var decision = MetraStationReadAuthorization.Evaluate(actor, StationB, "stations.read_all");

        Assert.False(decision.Allowed);
        Assert.Equal(MetraAuthorizationOutcome.DeniedScopeMismatch, decision.Outcome);
    }

    [Fact]
    public void Auditor_without_explicit_global_read_permission_is_denied()
    {
        var actor = Actor(Grant("auditor", "global_read", null, "stations.read"));

        var decision = MetraStationReadAuthorization.Evaluate(actor, StationB, "stations.read_all");

        Assert.False(decision.Allowed);
        Assert.Equal(MetraAuthorizationOutcome.DeniedPermissionMissing, decision.Outcome);
    }

    [Fact]
    public void Global_role_with_station_scope_does_not_get_cross_station_access()
    {
        var actor = Actor(Grant("auditor", "station", StationA, "stations.read_all"));

        var decision = MetraStationReadAuthorization.Evaluate(actor, StationB, "stations.read_all");

        Assert.False(decision.Allowed);
        Assert.Equal(MetraAuthorizationOutcome.DeniedScopeMismatch, decision.Outcome);
    }

    [Fact]
    public void Global_read_scope_does_not_authorize_write_permissions()
    {
        var actor = Actor(Grant("auditor", "global_read", null, "observations.write_all"));

        var decision = MetraStationReadAuthorization.Evaluate(actor, StationB, "observations.write_all");

        Assert.False(decision.Allowed);
        Assert.Equal(MetraAuthorizationOutcome.DeniedPermissionMissing, decision.Outcome);
    }

    [Fact]
    public void Inactive_profile_is_denied_even_when_grant_matches()
    {
        var actor = Actor(Grant("auditor", "global_read", null, "stations.read_all")) with
        {
            ProfileIsActive = false
        };

        var decision = MetraStationReadAuthorization.Evaluate(actor, StationB, "stations.read_all");

        Assert.False(decision.Allowed);
        Assert.Equal(MetraAuthorizationOutcome.DeniedInactiveProfile, decision.Outcome);
    }

    [Fact]
    public void Inactive_membership_is_denied_even_when_grant_matches()
    {
        var actor = Actor(Grant("network_department_head", "global_read", null, "stations.read_all")) with
        {
            MembershipIsActive = false
        };

        var decision = MetraStationReadAuthorization.Evaluate(actor, StationB, "stations.read_all");

        Assert.False(decision.Allowed);
        Assert.Equal(MetraAuthorizationOutcome.DeniedInactiveMembership, decision.Outcome);
    }

    [Fact]
    public void Expired_or_revoked_grant_is_not_accepted()
    {
        var grant = Grant("auditor", "global_read", null, "stations.read_all") with
        {
            IsActive = false
        };

        var decision = MetraStationReadAuthorization.Evaluate(Actor(grant), StationB, "stations.read_all");

        Assert.False(decision.Allowed);
        Assert.Equal(MetraAuthorizationOutcome.DeniedPermissionMissing, decision.Outcome);
    }

    [Fact]
    public void Missing_identity_and_empty_station_fail_closed()
    {
        Assert.False(MetraStationReadAuthorization.Evaluate(null, StationA, "stations.read_all").Allowed);
        Assert.False(MetraStationReadAuthorization.Evaluate(Actor(Grant("observer", "station", StationA, "stations.read_station")), Guid.Empty, "observations.read_station").Allowed);
    }

    [Fact]
    public void Malformed_permission_is_denied()
    {
        var actor = Actor(Grant("auditor", "global_read", null, "stations.read_all"));

        var decision = MetraStationReadAuthorization.Evaluate(actor, StationB, "stations.read_all\n");

        Assert.False(decision.Allowed);
    }

    [Fact]
    public void Station_scope_cannot_use_global_read_permission_even_for_own_station()
    {
        var actor = Actor(Grant("observer", "station", StationA, "stations.read_all"));

        var decision = MetraStationReadAuthorization.Evaluate(actor, StationA, "stations.read_all");

        Assert.False(decision.Allowed);
    }

    [Fact]
    public void Global_read_grant_with_station_identifier_is_rejected_as_ambiguous()
    {
        var grant = Grant("auditor", "global_read", StationA, "stations.read_all");
        var actor = Actor(grant);

        var decision = MetraStationReadAuthorization.Evaluate(actor, StationB, "stations.read_all");

        Assert.False(decision.Allowed);
        Assert.Equal(MetraAuthorizationOutcome.DeniedScopeMismatch, decision.Outcome);
    }

    [Fact]
    public void Global_read_grant_with_organization_identifier_is_rejected_as_ambiguous()
    {
        var grant = Grant("network_department_head", "global_read", null, "stations.read_all") with
        {
            OrganizationId = Guid.Parse("cccccccc-cccc-cccc-cccc-cccccccccccc")
        };
        var actor = Actor(grant);

        var decision = MetraStationReadAuthorization.Evaluate(actor, StationB, "stations.read_all");

        Assert.False(decision.Allowed);
        Assert.Equal(MetraAuthorizationOutcome.DeniedScopeMismatch, decision.Outcome);
    }

    [Fact]
    public void Station_scope_accepts_only_station_read_permissions()
    {
        var actor = Actor(Grant("station_manager", "station", StationA, "observations.read_station"));

        Assert.True(MetraStationReadAuthorization.Evaluate(
            actor, StationA, "observations.read_station").Allowed);
        Assert.False(MetraStationReadAuthorization.Evaluate(
            actor, StationA, "observations.read_all").Allowed);
    }

    private static MetraAuthorizationSnapshot Actor(params MetraAuthorizationGrant[] grants) =>
        new("validated-subject", true, true, grants);

    private static MetraAuthorizationGrant Grant(
        string role, string scope, Guid? station, params string[] permissions) =>
        new(role, scope, station, null, true, new HashSet<string>(permissions, StringComparer.Ordinal));
}