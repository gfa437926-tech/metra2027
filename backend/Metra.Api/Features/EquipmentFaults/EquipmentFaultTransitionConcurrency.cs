namespace Metra.Api.Features.EquipmentFaults;

/// <summary>
/// Outcomes expected from a future atomic transition write. The persistence adapter
/// must compare the stored status with ExpectedStatus and append the audit event in
/// the same transaction as the status update.
/// </summary>
public enum EquipmentFaultTransitionWriteResult
{
    Applied,
    Conflict,
    NotFoundOrWrongStation,
    Forbidden
}

/// <summary>
/// Contract for an atomic compare-and-transition operation. Implementations must
/// update only when the persisted station and status still match the supplied
/// expectations, and must append the immutable audit event atomically.
/// No database implementation is provided until schema approval.
/// </summary>
public interface IEquipmentFaultTransitionWriter
{
    Task<EquipmentFaultTransitionWriteResult> TryTransitionAsync(
        Guid faultId,
        Guid expectedStationId,
        EquipmentFaultStatus expectedCurrentStatus,
        EquipmentFaultStatus nextStatus,
        Guid actorId,
        string reason,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Pure guard used before requesting an atomic write. The writer must repeat this
/// check against the persisted row as the authoritative concurrency boundary.
/// </summary>
public static class EquipmentFaultTransitionConcurrency
{
    public static bool MatchesExpectedStatus(
        EquipmentFaultStatus expectedCurrentStatus,
        EquipmentFaultStatus persistedCurrentStatus) =>
        Enum.IsDefined(expectedCurrentStatus) &&
        Enum.IsDefined(persistedCurrentStatus) &&
        expectedCurrentStatus == persistedCurrentStatus;
}
