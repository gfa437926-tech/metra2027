using Metra.Api.Domain.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class EffectivePermissionAuthorizationTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 2, 12, 0, 0, TimeSpan.Zero);

    private static MetraPermissionGrant Grant(
        string permission = "observations.read",
        string? station = "station-a",
        DateTimeOffset? from = null,
        DateTimeOffset? until = null,
        DateTimeOffset? revoked = null)
        => new(permission, station, from ?? Now.AddDays(-1), until, revoked);

    private static MetraStationAssignment Assignment(
        string station = "station-a",
        DateTimeOffset? from = null,
        DateTimeOffset? until = null,
        DateTimeOffset? revoked = null)
        => new(station, from ?? Now.AddDays(-1), until, revoked);

    [Fact]
    public void Pending_account_cannot_use_a_valid_grant()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.PendingApproval, "observations.read", "station-a",
            [Grant()], [Assignment()], Now);

        Assert.False(result.IsAuthorized);
        Assert.Equal("account_not_active", result.Code);
    }

    [Fact]
    public void Station_operation_requires_both_permission_and_assignment()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "observations.read", "station-a",
            [Grant()], [], Now);

        Assert.False(result.IsAuthorized);
        Assert.Equal("station_assignment_required", result.Code);
    }

    [Fact]
    public void Assignment_alone_does_not_grant_permission()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "observations.read", "station-a",
            [], [Assignment()], Now);

        Assert.False(result.IsAuthorized);
        Assert.Equal("permission_not_granted", result.Code);
    }

    [Fact]
    public void Matching_active_permission_and_assignment_authorize()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "observations.read", "station-a",
            [Grant()], [Assignment()], Now);

        Assert.True(result.IsAuthorized);
        Assert.Equal("authorized", result.Code);
    }

    [Fact]
    public void Permission_for_another_station_is_not_a_wildcard()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "observations.read", "station-b",
            [Grant(station: "station-a")], [Assignment("station-b")], Now);

        Assert.False(result.IsAuthorized);
        Assert.Equal("permission_not_granted", result.Code);
    }

    [Fact]
    public void Global_permission_does_not_become_station_permission()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "users.manage", "station-a",
            [Grant(permission: "users.manage", station: null)], [Assignment()], Now);

        Assert.False(result.IsAuthorized);
        Assert.Equal("permission_not_granted", result.Code);
    }

    [Fact]
    public void Global_operation_requires_explicit_global_permission()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "users.manage", null,
            [Grant(permission: "users.manage", station: null)], [], Now);

        Assert.True(result.IsAuthorized);
    }

    [Fact]
    public void Expired_permission_is_not_effective_at_exclusive_end()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "observations.read", "station-a",
            [Grant(until: Now)], [Assignment()], Now);

        Assert.False(result.IsAuthorized);
        Assert.Equal("permission_not_granted", result.Code);
    }

    [Fact]
    public void Revoked_permission_is_not_effective_at_revocation_instant()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "observations.read", "station-a",
            [Grant(revoked: Now)], [Assignment()], Now);

        Assert.False(result.IsAuthorized);
        Assert.Equal("permission_not_granted", result.Code);
    }

    [Fact]
    public void Future_permission_is_not_effective()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "observations.read", "station-a",
            [Grant(from: Now.AddMinutes(1))], [Assignment()], Now);

        Assert.False(result.IsAuthorized);
    }

    [Fact]
    public void Revoked_station_assignment_blocks_access_even_with_permission()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "observations.read", "station-a",
            [Grant()], [Assignment(revoked: Now)], Now);

        Assert.False(result.IsAuthorized);
        Assert.Equal("station_assignment_required", result.Code);
    }

    [Fact]
    public void Invalid_validity_window_fails_closed()
    {
        var malformed = Grant(from: Now, until: Now);

        Assert.False(malformed.IsEffectiveAt(Now));
    }

    [Fact]
    public void Station_assignment_end_is_exclusive()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "observations.read", "station-a",
            [Grant()], [Assignment(until: Now)], Now);

        Assert.False(result.IsAuthorized);
        Assert.Equal("station_assignment_required", result.Code);
    }

    [Fact]
    public void Non_utc_grant_timestamps_fail_closed()
    {
        var nonUtcGrant = new MetraPermissionGrant(
            "observations.read", "station-a",
            Now.ToOffset(TimeSpan.FromHours(3)), null, null);

        Assert.False(nonUtcGrant.IsEffectiveAt(Now));
    }

    [Fact]
    public void Non_utc_assignment_timestamps_fail_closed()
    {
        var nonUtcAssignment = new MetraStationAssignment(
            "station-a", Now.ToOffset(TimeSpan.FromHours(3)), null, null);

        Assert.False(nonUtcAssignment.IsEffectiveAt(Now));
    }

    [Fact]
    public void Non_utc_evaluation_instant_fails_closed()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            MetraAccountAccessState.Active, "observations.read", "station-a",
            [Grant()], [Assignment()], Now.ToOffset(TimeSpan.FromHours(3)));

        Assert.False(result.IsAuthorized);
        Assert.Equal("authorization_time_invalid", result.Code);
    }

    [Fact]
    public void Unknown_account_state_fails_closed()
    {
        var result = EffectivePermissionAuthorization.Authorize(
            (MetraAccountAccessState)999, "observations.read", "station-a",
            [Grant()], [Assignment()], Now);

        Assert.False(result.IsAuthorized);
        Assert.Equal("account_state_invalid", result.Code);
    }
}
