namespace Metra.Api.Features.EquipmentFaults;

public enum EquipmentFaultTransitionExecutionResult
{
    Applied,
    Conflict,
    NotFoundOrWrongStation,
    Forbidden,
    InvalidRequest
}

/// <summary>
/// Coordinates authorization and the atomic transition writer. The writer remains
/// the final authority for persisted station ownership and expected status.
/// </summary>
public sealed class EquipmentFaultTransitionService(
    EquipmentFaultApplicationService access,
    IEquipmentFaultTransitionWriter writer)
{
    public async Task<EquipmentFaultTransitionExecutionResult> ExecuteAsync(
        Guid actorId,
        Guid routeStationId,
        Guid faultId,
        EquipmentFaultStatus expectedCurrentStatus,
        EquipmentFaultStatus nextStatus,
        string? reason,
        CancellationToken cancellationToken = default)
    {
        if (actorId == Guid.Empty ||
            routeStationId == Guid.Empty ||
            faultId == Guid.Empty ||
            !Enum.IsDefined(expectedCurrentStatus) ||
            !Enum.IsDefined(nextStatus) ||
            !EquipmentFaultPolicy.TryGetRequiredPermission(
                expectedCurrentStatus, nextStatus, out _) ||
            reason is null ||
            reason != reason.Trim() ||
            reason.Length is < 5 or > 1000)
        {
            return EquipmentFaultTransitionExecutionResult.InvalidRequest;
        }

        var accessResult = await access.AuthorizeTransitionAsync(
            actorId,
            routeStationId,
            faultId,
            expectedCurrentStatus,
            nextStatus,
            cancellationToken);

        if (accessResult != EquipmentFaultAccessResult.Allowed)
        {
            return accessResult switch
            {
                EquipmentFaultAccessResult.NotFoundOrWrongStation =>
                    EquipmentFaultTransitionExecutionResult.NotFoundOrWrongStation,
                _ => EquipmentFaultTransitionExecutionResult.Forbidden
            };
        }

        try
        {
            var writeResult = await writer.TryTransitionAsync(
                faultId,
                routeStationId,
                expectedCurrentStatus,
                nextStatus,
                actorId,
                reason,
                cancellationToken);

            return writeResult switch
            {
                EquipmentFaultTransitionWriteResult.Applied =>
                    EquipmentFaultTransitionExecutionResult.Applied,
                EquipmentFaultTransitionWriteResult.Conflict =>
                    EquipmentFaultTransitionExecutionResult.Conflict,
                EquipmentFaultTransitionWriteResult.NotFoundOrWrongStation =>
                    EquipmentFaultTransitionExecutionResult.NotFoundOrWrongStation,
                EquipmentFaultTransitionWriteResult.Forbidden =>
                    EquipmentFaultTransitionExecutionResult.Forbidden,
                _ => EquipmentFaultTransitionExecutionResult.Forbidden
            };
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            // A failed write must not be reported as a successful transition.
            return EquipmentFaultTransitionExecutionResult.Forbidden;
        }
    }
}
