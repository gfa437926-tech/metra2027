namespace Metra.Api.Security;

/// <summary>
/// One authoritative lookup for an actor's current account state and requested
/// permission grant. A null result means no grant exists.
/// </summary>
public interface IMetraPermissionAuthorizationDataSource
{
    Task<MetraPermissionGrantFacts?> GetGrantFactsAsync(
        string actorSubject,
        string permission,
        CancellationToken cancellationToken);
}

/// <summary>
/// Grant dates are UTC instants. Start is inclusive; end and revocation are
/// exclusive. A null end/revocation means no scheduled end/revocation.
/// </summary>
public sealed record MetraPermissionGrantFacts(
    bool ActorIsActive,
    bool GrantExists,
    DateTimeOffset ValidFromUtc,
    DateTimeOffset? ValidToUtc,
    DateTimeOffset? RevokedAtUtc);

/// <summary>
/// Checks a current authoritative grant on every authorization evaluation.
/// It deliberately does not accept permission claims or role names as proof.
/// </summary>
public sealed class AuthoritativeMetraPermissionGrantEvaluator(
    IMetraPermissionAuthorizationDataSource dataSource,
    TimeProvider timeProvider)
    : IMetraPermissionGrantEvaluator
{
    public async Task<bool> HasPermissionAsync(
        string actorSubject,
        string permission,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(actorSubject) ||
            !MetraPermissions.All.Contains(permission, StringComparer.Ordinal))
        {
            return false;
        }

        try
        {
            var facts = await dataSource.GetGrantFactsAsync(
                actorSubject, permission, cancellationToken);

            if (facts is not { ActorIsActive: true, GrantExists: true })
            {
                return false;
            }

            var now = timeProvider.GetUtcNow();
            return facts.ValidFromUtc <= now &&
                (facts.ValidToUtc is null || now < facts.ValidToUtc) &&
                (facts.RevokedAtUtc is null || now < facts.RevokedAtUtc);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            // Unknown authorization state must never grant an action.
            return false;
        }
    }
}
