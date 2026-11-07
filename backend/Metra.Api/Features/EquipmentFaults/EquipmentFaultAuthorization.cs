using Metra.Api.Security;

namespace Metra.Api.Features.EquipmentFaults;

/// <summary>
/// Central fail-closed authorization adapter for equipment-fault handlers.
/// The station identifier must come from the route and, for record operations,
/// must first be matched against the persisted fault's owning station.
/// </summary>
public static class EquipmentFaultAuthorization
{
    public static async Task<bool> HasStationPermissionAsync(
        IStationAuthorizationService authorization,
        Guid userId,
        Guid stationId,
        string permissionCode,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(authorization);

        if (!authorization.IsConfigured ||
            userId == Guid.Empty ||
            stationId == Guid.Empty ||
            string.IsNullOrWhiteSpace(permissionCode))
        {
            return false;
        }

        try
        {
            return await authorization.HasStationPermissionAsync(
                userId, stationId, permissionCode, cancellationToken);
        }
        catch (HttpRequestException)
        {
            // A failed authorization dependency must never grant access.
            return false;
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            // Treat an upstream timeout as denial, but preserve caller cancellation.
            return false;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            // Preserve cancellation initiated by the caller.
            throw;
        }
        catch (Exception)
        {
            // Unexpected authorization-provider failures must fail closed.
            return false;
        }
    }

    public static async Task<bool> CanTransitionAsync(
        IStationAuthorizationService authorization,
        Guid userId,
        Guid stationId,
        EquipmentFaultStatus currentStatus,
        EquipmentFaultStatus nextStatus,
        CancellationToken cancellationToken = default)
    {
        if (!EquipmentFaultPolicy.TryGetRequiredPermission(
                currentStatus, nextStatus, out var requiredPermission))
        {
            return false;
        }

        return await HasStationPermissionAsync(
            authorization, userId, stationId, requiredPermission, cancellationToken);
    }
}
