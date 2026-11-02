namespace Metra.Api.Security;

/// <summary>
/// Resolves the canonical station owning a resource from authoritative persistence.
/// A null result means the resource is missing, deleted, unclassified or not station-scoped.
/// Implementations must not use the caller-supplied descriptor StationId as ownership evidence.
/// </summary>
public interface IMetraResourceStationResolver
{
    Task<string?> ResolveStationIdAsync(
        string resourceType,
        string resourceId,
        CancellationToken cancellationToken);
}

/// <summary>
/// Reads the actor's current account state and active station assignments from
/// authoritative METRA authorization data. Returned station identifiers must be canonical.
/// </summary>
public interface IMetraActorStationAccessStore
{
    Task<bool> IsActorActiveAsync(
        string actorSubject,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<string>> GetActiveStationAssignmentsAsync(
        string actorSubject,
        CancellationToken cancellationToken);
}

/// <summary>
/// Provider-neutral station-scope evaluator. It deliberately ignores the optional
/// StationId carried by the request descriptor and resolves ownership independently.
/// It is not registered by default: production must supply reviewed persistence adapters.
/// </summary>
public sealed class StationScopedMetraResourceAccessEvaluator(
    IMetraResourceStationResolver resourceStationResolver,
    IMetraActorStationAccessStore actorStationAccessStore,
    ILogger<StationScopedMetraResourceAccessEvaluator> logger)
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
            if (!await actorStationAccessStore.IsActorActiveAsync(
                    actorSubject, cancellationToken))
            {
                return false;
            }

            var actualStationId = await resourceStationResolver.ResolveStationIdAsync(
                resource.ResourceType,
                resource.ResourceId,
                cancellationToken);

            if (string.IsNullOrWhiteSpace(actualStationId))
            {
                return false;
            }

            var activeAssignments = await actorStationAccessStore.GetActiveStationAssignmentsAsync(
                actorSubject, cancellationToken);

            return activeAssignments.Any(assignment =>
                !string.IsNullOrWhiteSpace(assignment) &&
                string.Equals(assignment, actualStationId, StringComparison.Ordinal));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                exception,
                "METRA resource authorization data could not be resolved; access denied.");
            return false;
        }
    }
}
