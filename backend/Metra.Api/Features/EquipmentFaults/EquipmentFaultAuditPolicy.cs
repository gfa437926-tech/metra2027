namespace Metra.Api.Features.EquipmentFaults;

/// <summary>
/// Validates audit facts before they are handed to the atomic persistence writer.
/// The writer must append the entry in the same transaction as its state change.
/// </summary>
public static class EquipmentFaultAuditPolicy
{
    public static string? Validate(EquipmentFaultAuditEntry? entry)
    {
        if (entry is null)
            return "invalid_audit_entry";

        if (entry.FaultId == Guid.Empty || entry.ActorId == Guid.Empty)
            return "invalid_audit_identity";

        if (!Enum.IsDefined(entry.NewStatus))
            return "invalid_audit_status";

        if (entry.PreviousStatus is null)
        {
            // A creation event has no prior state; it must establish Submitted.
            if (entry.NewStatus != EquipmentFaultStatus.Submitted)
                return "invalid_audit_transition";
        }
        else
        {
            if (!Enum.IsDefined(entry.PreviousStatus.Value))
                return "invalid_audit_status";

            if (!EquipmentFaultPolicy.TryGetRequiredPermission(
                    entry.PreviousStatus.Value, entry.NewStatus, out _))
                return "invalid_audit_transition";
        }

        if (entry.OccurredAt == default)
            return "invalid_audit_timestamp";

        if (string.IsNullOrWhiteSpace(entry.Reason) ||
            entry.Reason != entry.Reason.Trim() ||
            entry.Reason.Length is < 5 or > 1000)
            return "invalid_audit_reason";

        return null;
    }

    public static EquipmentFaultAuditEntry Create(
        Guid faultId,
        Guid actorId,
        DateTimeOffset occurredAt,
        EquipmentFaultStatus? previousStatus,
        EquipmentFaultStatus newStatus,
        string reason) =>
        new(faultId, actorId, occurredAt, previousStatus, newStatus, reason);
}
