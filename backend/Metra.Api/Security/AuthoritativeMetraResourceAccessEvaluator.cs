using Metra.Api.Domain.Identity;

namespace Metra.Api.Security;

/// <summary>
/// One authoritative read model for an object-level authorization decision.
/// Implementations must resolve the resource's canonical station relationship
/// and the actor's assignment records from trusted persistence.
/// </summary>
public interface IMetraResourceAuthorizationDataSource
{
    Task<MetraResourceAuthorizationFacts?> GetFactsAsync(
        string actorSubject,
        string resourceType,
        string resourceId,
        CancellationToken cancellationToken);
}

/// <summary>
/// Assignment dates are UTC instants. A null ValidToUtc means no scheduled end;
/// RevokedAtUtc, when present, terminates the assignment immediately.
/// </summary>
public sealed record MetraStationAssignmentFacts(
    string StationId,
    DateTimeOffset ValidFromUtc,
    DateTimeOffset? ValidToUtc,
    DateTimeOffset? RevokedAtUtc);

/// <summary>
/// Facts returned by one authoritative authorization lookup. The station ID
/// must come from the persisted resource, never from the request descriptor.
/// </summary>
public sealed record MetraResourceAuthorizationFacts(
    bool ActorIsActive,
    bool ResourceExists,
    string? CanonicalStationId,
    IReadOnlyCollection<MetraStationAssignmentFacts>? StationAssignments);

/// <summary>
/// Fail-closed evaluator applying account, resource and time-bounded station
/// assignment checks. It deliberately ignores the descriptor's optional
/// StationId because that value is untrusted.
/// </summary>
public sealed class AuthoritativeMetraResourceAccessEvaluator(
    IMetraResourceAuthorizationDataSource dataSource,
    TimeProvider timeProvider)
    : IMetraResourceAccessEvaluator
{
    public async Task<bool> CanAccessAsync(
        string actorSubject,
        MetraResourceDescriptor resource,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(actorSubject) ||
            string.IsNullOrWhiteSpace(resource.ResourceType) ||
            string.IsNullOrWhiteSpace(resource.ResourceId))
        {
            return false;
        }

        try
        {
            var facts = await dataSource.GetFactsAsync(
                actorSubject,
                resource.ResourceType,
                resource.ResourceId,
                cancellationToken);

            if (facts is not
                {
                    ActorIsActive: true,
                    ResourceExists: true,
                    CanonicalStationId: not null,
                    StationAssignments: not null
                } || string.IsNullOrWhiteSpace(facts.CanonicalStationId))
            {
                return false;
            }

            var now = timeProvider.GetUtcNow();
            if (now.Offset != TimeSpan.Zero ||
                !MetraAccessRecordPolicy.ValidateAssignment(
                    new MetraStationAssignment(facts.CanonicalStationId, now, null, null)).IsValid)
            {
                return false;
            }

            if (facts.StationAssignments.Any(assignment =>
                    assignment is null ||
                    !MetraAccessRecordPolicy.ValidateAssignment(
                        new MetraStationAssignment(
                            assignment.StationId,
                            assignment.ValidFromUtc,
                            assignment.ValidToUtc,
                            assignment.RevokedAtUtc)).IsValid))
            {
                return false;
            }

            return facts.StationAssignments.Any(assignment =>
                string.Equals(
                    assignment.StationId,
                    facts.CanonicalStationId,
                    StringComparison.Ordinal) &&
                assignment.ValidFromUtc <= now &&
                (assignment.ValidToUtc is null || now < assignment.ValidToUtc) &&
                (assignment.RevokedAtUtc is null || now < assignment.RevokedAtUtc));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            // Persistence errors and unknown states must never become an allow.
            return false;
        }
    }
}
