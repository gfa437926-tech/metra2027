using Metra.Api.Features.EquipmentFaults;

namespace Metra.Api.Tests.EquipmentFaults;

public sealed class EquipmentFaultStationScopeTests
{
    [Fact]
    public void Matching_route_and_persisted_station_is_allowed()
    {
        var stationId = Guid.NewGuid();

        Assert.True(EquipmentFaultStationScope.MatchesPersistedOwner(stationId, stationId));
    }

    [Fact]
    public void Different_station_is_denied_even_when_both_ids_are_valid()
    {
        Assert.False(EquipmentFaultStationScope.MatchesPersistedOwner(
            Guid.NewGuid(), Guid.NewGuid()));
    }

    [Fact]
    public void Empty_route_station_is_denied()
    {
        Assert.False(EquipmentFaultStationScope.MatchesPersistedOwner(
            Guid.Empty, Guid.NewGuid()));
    }

    [Fact]
    public void Empty_persisted_owner_is_denied()
    {
        Assert.False(EquipmentFaultStationScope.MatchesPersistedOwner(
            Guid.NewGuid(), Guid.Empty));
    }

    [Fact]
    public void Both_empty_station_ids_are_denied()
    {
        Assert.False(EquipmentFaultStationScope.MatchesPersistedOwner(
            Guid.Empty, Guid.Empty));
    }
}
