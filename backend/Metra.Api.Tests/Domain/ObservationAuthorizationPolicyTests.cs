using Metra.Api.Domain.Observations;
using Xunit;

namespace Metra.Api.Tests;

public sealed class ObservationAuthorizationPolicyTests
{
    private static ObservationActorContext Actor(
        string user = "user-1",
        string station = "station-1",
        bool active = true,
        params ObservationPermission[] permissions)
        => new(user, station, active, permissions.ToHashSet());

    private static ObservationResourceContext Resource(
        string station = "station-1",
        string owner = "user-1")
        => new(station, owner);

    [Fact]
    public void Allows_operation_with_active_assignment_matching_station_and_permission()
    {
        var result = ObservationAuthorizationPolicy.Authorize(
            Actor(permissions: [ObservationPermission.Approve]),
            Resource(),
            ObservationPermission.Approve);

        Assert.True(result.IsAuthorized);
        Assert.Null(result.ErrorCode);
    }

    [Fact]
    public void Denies_missing_actor()
    {
        var result = ObservationAuthorizationPolicy.Authorize(
            null, Resource(), ObservationPermission.Approve);

        Assert.False(result.IsAuthorized);
        Assert.Equal("unauthenticated", result.ErrorCode);
    }

    [Fact]
    public void Denies_inactive_station_assignment()
    {
        var result = ObservationAuthorizationPolicy.Authorize(
            Actor(active: false, permissions: [ObservationPermission.Approve]),
            Resource(),
            ObservationPermission.Approve);

        Assert.Equal("inactive_station_assignment", result.ErrorCode);
    }

    [Fact]
    public void Denies_access_to_another_station()
    {
        var result = ObservationAuthorizationPolicy.Authorize(
            Actor(station: "station-2", permissions: [ObservationPermission.Approve]),
            Resource(station: "station-1"),
            ObservationPermission.Approve);

        Assert.Equal("station_scope_violation", result.ErrorCode);
    }

    [Fact]
    public void Denies_missing_permission_even_when_assignment_is_active()
    {
        var result = ObservationAuthorizationPolicy.Authorize(
            Actor(permissions: [ObservationPermission.Create]),
            Resource(),
            ObservationPermission.Approve);

        Assert.Equal("permission_denied", result.ErrorCode);
    }

    [Fact]
    public void Denies_editing_another_users_draft()
    {
        var result = ObservationAuthorizationPolicy.Authorize(
            Actor(permissions: [ObservationPermission.EditOwnDraft]),
            Resource(owner: "user-2"),
            ObservationPermission.EditOwnDraft);

        Assert.Equal("not_observation_owner", result.ErrorCode);
    }

    [Fact]
    public void Allows_reviewer_to_review_observation_created_by_another_user()
    {
        var result = ObservationAuthorizationPolicy.Authorize(
            Actor(permissions: [ObservationPermission.Review]),
            Resource(owner: "user-2"),
            ObservationPermission.Review);

        Assert.True(result.IsAuthorized);
    }
}