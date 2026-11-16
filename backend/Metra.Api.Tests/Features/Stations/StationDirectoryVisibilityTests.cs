using Metra.Api.Features.Stations;
using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests.Features.Stations;

public sealed class StationDirectoryVisibilityTests
{
    [Fact]
    public async Task Assigned_observer_sees_station_only_after_create_permission_is_confirmed()
    {
        var authorization = new FakeAuthorization(stationPermission: code => code == "observation.create");
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();

        var allowed = await StationDirectoryVisibility.CanViewAsync(
            authorization, userId, stationId, CancellationToken.None);

        Assert.True(allowed);
        Assert.Equal(new[] { "observation.create" }, authorization.StationPermissionCalls);
        Assert.Empty(authorization.AuthorityPermissionCalls);
    }

    [Fact]
    public async Task Station_auditor_can_be_visible_through_review_permission()
    {
        var authorization = new FakeAuthorization(stationPermission: code => code == "observation.review");

        var allowed = await StationDirectoryVisibility.CanViewAsync(
            authorization, Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None);

        Assert.True(allowed);
        Assert.Contains("observation.review", authorization.StationPermissionCalls);
        Assert.Empty(authorization.AuthorityPermissionCalls);
    }

    [Fact]
    public async Task Authority_scoped_catalogue_reviewer_can_see_owner_authority_stations()
    {
        var authorization = new FakeAuthorization(
            stationPermission: _ => false,
            authorityPermission: code => code == "stations.catalogue.review");

        var allowed = await StationDirectoryVisibility.CanViewAsync(
            authorization, Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None);

        Assert.True(allowed);
        Assert.Equal(5, authorization.StationPermissionCalls.Count);
        Assert.Equal(new[] { "stations.catalogue.review" }, authorization.AuthorityPermissionCalls);
    }

    [Fact]
    public async Task User_without_any_station_or_authority_permission_sees_no_station()
    {
        var authorization = new FakeAuthorization(stationPermission: _ => false);

        var allowed = await StationDirectoryVisibility.CanViewAsync(
            authorization, Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None);

        Assert.False(allowed);
        Assert.Equal(5, authorization.StationPermissionCalls.Count);
        Assert.Equal(new[] { "stations.catalogue.review" }, authorization.AuthorityPermissionCalls);
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public async Task Missing_authorization_configuration_or_empty_identity_fails_closed(
        bool configured,
        bool emptyUser)
    {
        var authorization = new FakeAuthorization(
            isConfigured: configured,
            stationPermission: _ => true,
            authorityPermission: _ => true);

        var allowed = await StationDirectoryVisibility.CanViewAsync(
            authorization,
            emptyUser ? Guid.Empty : Guid.NewGuid(),
            Guid.NewGuid(),
            CancellationToken.None);

        Assert.False(allowed);
        Assert.Empty(authorization.StationPermissionCalls);
        Assert.Empty(authorization.AuthorityPermissionCalls);
    }

    private sealed class FakeAuthorization(
        Func<string, bool> stationPermission,
        Func<string, bool>? authorityPermission = null,
        bool isConfigured = true) : IStationAuthorizationService
    {
        public bool IsConfigured { get; } = isConfigured;
        public List<string> StationPermissionCalls { get; } = [];
        public List<string> AuthorityPermissionCalls { get; } = [];

        public Task<bool> HasStationPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default)
        {
            StationPermissionCalls.Add(permissionCode);
            return Task.FromResult(stationPermission(permissionCode));
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default)
        {
            AuthorityPermissionCalls.Add(permissionCode);
            return Task.FromResult(authorityPermission?.Invoke(permissionCode) ?? false);
        }
    }
}
