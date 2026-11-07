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
