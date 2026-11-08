namespace Metra.Api.Features.EquipmentFaults;

/// <summary>
/// Persistence port for creating a validated station-scoped fault report.
/// Implementations must append the initial audit event atomically.
/// </summary>
public interface IEquipmentFaultSubmissionWriter
{
    Task<Guid> CreateAsync(
        Guid actorId,
        Guid stationId,
        EquipmentFaultSubmission submission,
        CancellationToken cancellationToken = default);
}
