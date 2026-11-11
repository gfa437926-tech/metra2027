using Metra.Api.Security;

namespace Metra.Api.Infrastructure.Persistence;

/// <summary>
/// Independently validates the target assignee against the same station boundary.
/// </summary>
public static class StationAssigneeAuthorization
{
    public static Task<bool> CanAssignEquipmentFaultAsync(
        IStationAuthorizationService authorization, Guid assigneeUserId, Guid stationId,
        CancellationToken cancellationToken = default) =>
        IsAuthorizedAsync(authorization, assigneeUserId, stationId,
            "equipment_fault.update", cancellationToken);

    public static Task<bool> CanAssignSupportIncidentAsync(
        IStationAuthorizationService authorization, Guid assigneeUserId, Guid stationId,
        CancellationToken cancellationToken = default) =>
        IsAuthorizedAsync(authorization, assigneeUserId, stationId,
            "support_incident.update", cancellationToken);

    private static Task<bool> IsAuthorizedAsync(
        IStationAuthorizationService authorization, Guid assigneeUserId, Guid stationId,
        string permissionCode, CancellationToken cancellationToken)
    {
        if (assigneeUserId == Guid.Empty || stationId == Guid.Empty)
            return Task.FromResult(false);

        return authorization.HasStationPermissionAsync(
            assigneeUserId, stationId, permissionCode, cancellationToken);
    }
}
