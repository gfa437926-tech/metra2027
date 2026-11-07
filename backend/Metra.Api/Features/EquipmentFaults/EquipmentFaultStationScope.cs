namespace Metra.Api.Features.EquipmentFaults;

/// <summary>
/// Enforces the route-to-record station boundary for equipment-fault reads and
/// mutations. Call only after loading the persisted record by its fault ID.
/// Never use a route station ID as a substitute for the record's owner.
/// </summary>
public static class EquipmentFaultStationScope
{
    public static bool MatchesPersistedOwner(Guid routeStationId, Guid persistedStationId) =>
        routeStationId != Guid.Empty &&
        persistedStationId != Guid.Empty &&
        routeStationId == persistedStationId;
}
