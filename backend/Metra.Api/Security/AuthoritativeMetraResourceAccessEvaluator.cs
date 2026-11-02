namespace Metra.Api.Security;

/// <summary>
/// One authoritative read model for an object-level authorization decision.
/// Implementations must resolve the resource's canonical station relationship
/// and the actor's currently active assignment from trusted persistence.
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
/// Facts returned by one authoritative authorization lookup. The station ID
/// must come from the persisted resource, never from the request descriptor.
/// </summary>
public sealed record MetraResourceAuthorizationFacts(
    bool ActorIsActive,
    bool ResourceExists,
    string? CanonicalStationId,
    bool HasActiveStationAssignment);

/// <summary>
/// Fail-closed evaluator that applies active-account, resource-existence and
/// active-station-assignment checks to authoritative facts. It deliberately
/// ignores the descriptor's optional StationId because that value is untrusted.
/// </summary>
public sealed class AuthoritativeMetraResourceAccessEvaluator(
    IMetraResourceAuthorizationDataSource dataSource)
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

            return facts is
            {
                ActorIsActive: true,
                ResourceExists: true,
                HasActiveStationAssignment: true
            } && !string.IsNullOrWhiteSpace(facts.CanonicalStationId);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch
        {
            // Persistence errors and unknown states must never become an allow.
            return false;
        }
    }
}
