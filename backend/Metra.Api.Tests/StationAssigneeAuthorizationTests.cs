using Metra.Api.Infrastructure.Persistence;
using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests;

public sealed class StationAssigneeAuthorizationTests
{
    [Fact]
    public async Task Equipment_fault_assignee_requires_update_permission_on_same_station()
    {
        var assignee = Guid.NewGuid();
        var station = Guid.NewGuid();
        var auth = new FakeAuthorization(assignee, station, "equipment_fault.update");
        Assert.True(await StationAssigneeAuthorization.CanAssignEquipmentFaultAsync(auth, assignee, station));
        Assert.Equal(assignee, auth.LastUserId);
        Assert.Equal(station, auth.LastStationId);
        Assert.Equal("equipment_fault.update", auth.LastPermission);
    }

    [Fact]
    public async Task Equipment_fault_assignee_from_another_station_is_denied()
    {
        var auth = new FakeAuthorization(Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.update");
        Assert.False(await StationAssigneeAuthorization.CanAssignEquipmentFaultAsync(
            auth, Guid.NewGuid(), Guid.NewGuid()));
    }

    [Fact]
    public async Task Support_assignee_requires_update_permission_on_same_station()
    {
        var assignee = Guid.NewGuid();
        var station = Guid.NewGuid();
        var auth = new FakeAuthorization(assignee, station, "support_incident.update");
        Assert.True(await StationAssigneeAuthorization.CanAssignSupportIncidentAsync(auth, assignee, station));
        Assert.Equal(assignee, auth.LastUserId);
        Assert.Equal(station, auth.LastStationId);
        Assert.Equal("support_incident.update", auth.LastPermission);
    }

    [Fact]
    public async Task Support_assignee_without_update_permission_is_denied()
    {
        var assignee = Guid.NewGuid();
        var station = Guid.NewGuid();
        var auth = new FakeAuthorization(assignee, station, "support_incident.read");
        Assert.False(await StationAssigneeAuthorization.CanAssignSupportIncidentAsync(auth, assignee, station));
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public async Task Empty_assignee_or_station_is_denied_without_lookup(bool emptyAssignee, bool emptyStation)
    {
        var auth = new FakeAuthorization(Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.update");
        var result = await StationAssigneeAuthorization.CanAssignEquipmentFaultAsync(
            auth, emptyAssignee ? Guid.Empty : Guid.NewGuid(), emptyStation ? Guid.Empty : Guid.NewGuid());
        Assert.False(result);
        Assert.Equal(0, auth.CallCount);
    }

    private sealed class FakeAuthorization(Guid user, Guid station, string permission) : IStationAuthorizationService
    {
        public bool IsConfigured => true;
        public int CallCount { get; private set; }
        public Guid LastUserId { get; private set; }
        public Guid LastStationId { get; private set; }
        public string? LastPermission { get; private set; }

        public Task<bool> HasStationPermissionAsync(Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            LastUserId = userId;
            LastStationId = stationId;
            LastPermission = permissionCode;
            return Task.FromResult(userId == user && stationId == station && permissionCode == permission);
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(Guid userId, Guid stationId,
            string permissionCode, CancellationToken cancellationToken = default) => Task.FromResult(false);
    }
}
