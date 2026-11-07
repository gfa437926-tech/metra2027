using Metra.Api.Security;

namespace Metra.Api.Features.EquipmentFaults;

/// <summary>
/// Minimal persistence boundary required by record-level operations.
/// Implementations must read the persisted owner from the authoritative record;
/// they must never infer ownership from request data.
/// </summary>
public interface IEquipmentFaultStationReader
{
    Task<Guid?> GetOwningStationIdAsync(Guid faultId, CancellationToken cancellationToken);
}

public enum EquipmentFaultAccessResult
{
    Allowed,
    NotFoundOrWrongStation,
    Forbidden
}

/// <summary>
/// Application-layer authorization orchestration. Persistence writes and database
/// schema are deliberately kept outside this service until the schema is approved.
/// </summary>
public sealed class EquipmentFaultApplicationService(
    IStationAuthorizationService authorization,
    IEquipmentFaultStationReader stationReader)
{
    public async Task<bool> CanCreateAsync(
        Guid userId,
        Guid stationId,
        EquipmentFaultSubmission? submission,
        DateTimeOffset now,
        CancellationToken cancellationToken = default)
    {
        if (EquipmentFaultPolicy.ValidateSubmission(submission, now) is not null)
            return false;

        return await EquipmentFaultAuthorization.HasStationPermissionAsync(
            authorization, userId, stationId, "equipment_fault.create", cancellationToken);
    }

    /// <summary>
    /// Authorizes a lifecycle transition only after verifying the persisted owner.
    /// The required permission is derived from domain policy, never accepted from the caller.
    /// </summary>
    public async Task<EquipmentFaultAccessResult> AuthorizeTransitionAsync(
        Guid userId,
        Guid routeStationId,
        Guid faultId,
        EquipmentFaultStatus currentStatus,
        EquipmentFaultStatus nextStatus,
        CancellationToken cancellationToken = default)
    {
        if (!EquipmentFaultPolicy.TryGetRequiredPermission(
                currentStatus, nextStatus, out var requiredPermission))
            return EquipmentFaultAccessResult.Forbidden;

        return await AuthorizeRecordAsync(
            userId, routeStationId, faultId, requiredPermission, cancellationToken);
    }

    public async Task<EquipmentFaultAccessResult> AuthorizeRecordAsync(
        Guid userId,
        Guid routeStationId,
        Guid faultId,
        string permissionCode,
        CancellationToken cancellationToken = default)
    {
        if (userId == Guid.Empty || routeStationId == Guid.Empty ||
            faultId == Guid.Empty || string.IsNullOrWhiteSpace(permissionCode))
            return EquipmentFaultAccessResult.NotFoundOrWrongStation;

        Guid? persistedStationId;
        try
        {
            persistedStationId = await stationReader.GetOwningStationIdAsync(
                faultId, cancellationToken);
        }
        catch (HttpRequestException)
        {
            return EquipmentFaultAccessResult.Forbidden;
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return EquipmentFaultAccessResult.Forbidden;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            // Caller cancellation is control flow, not an authorization denial.
            throw;
        }
        catch (Exception)
        {
            // Unexpected repository failures must fail closed before permission checks.
            return EquipmentFaultAccessResult.Forbidden;
        }

        if (persistedStationId is null ||
            !EquipmentFaultStationScope.MatchesPersistedOwner(routeStationId, persistedStationId.Value))
            return EquipmentFaultAccessResult.NotFoundOrWrongStation;

        var allowed = await EquipmentFaultAuthorization.HasStationPermissionAsync(
            authorization, userId, routeStationId, permissionCode, cancellationToken);

        return allowed
            ? EquipmentFaultAccessResult.Allowed
            : EquipmentFaultAccessResult.Forbidden;
    }
}
