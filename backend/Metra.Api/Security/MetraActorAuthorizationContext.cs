namespace Metra.Api.Security;

/// <summary>
/// A single, consistent authorization read for one actor, action and resource.
/// Infrastructure implementations must load all facts from one transactionally
/// consistent snapshot (or an equivalent versioned snapshot).
/// </summary>
public interface IMetraActorAuthorizationContextDataSource
{
    Task<MetraActorAuthorizationContext?> GetContextAsync(
        string actorSubject,
        string permission,
        MetraResourceDescriptor resource,
        CancellationToken cancellationToken);
}

/// <summary>
/// Facts used together for one authorization decision. Null nested facts mean
/// that the requested grant/resource relationship was not found.
/// </summary>
public sealed record MetraActorAuthorizationContext(
    bool ActorIsActive,
    MetraPermissionGrantFacts? PermissionGrant,
    MetraResourceAuthorizationFacts? ResourceAccess);

/// <summary>
/// Evaluates action permission and object/station scope from one authoritative
/// snapshot. This avoids combining two independently-timed reads for a single
/// sensitive operation. It does not replace endpoint-level authentication.
/// </summary>
public sealed class AuthoritativeMetraActorAuthorizationContextProvider(
    IMetraActorAuthorizationContextDataSource dataSource,
    TimeProvider timeProvider)
{
    public async Task<bool> CanPerformOnResourceAsync(
        string actorSubject,
        string permission,
        MetraResourceDescriptor resource,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(actorSubject) ||
            !MetraPermissions.All.Contains(permission, StringComparer.Ordinal) ||
            string.IsNullOrWhiteSpace(resource.ResourceType) ||
            string.IsNullOrWhiteSpace(resource.ResourceId) ||
            (resource.StationId is not null && string.IsNullOrWhiteSpace(resource.StationId)))
        {
            return false;
        }

        try
        {
            var context = await dataSource.GetContextAsync(
                actorSubject, permission, resource, cancellationToken);

            if (context is not { ActorIsActive: true, PermissionGrant: not null, ResourceAccess: not null })
            {
                return false;
            }

            var now = timeProvider.GetUtcNow();
            var grant = context.PermissionGrant;
            if (!grant.ActorIsActive ||
                !grant.GrantExists ||
                grant.ValidFromUtc > now ||
                (grant.ValidToUtc is not null && now >= grant.ValidToUtc) ||
                (grant.RevokedAtUtc is not null && now >= grant.RevokedAtUtc))
            {
                return false;
            }

            var access = context.ResourceAccess;
            if (!access.ActorIsActive ||
                !access.ResourceExists ||
                string.IsNullOrWhiteSpace(access.CanonicalStationId) ||
                access.StationAssignments is null)
            {
                return false;
            }

            return access.StationAssignments.Any(assignment =>
                string.Equals(
                    assignment.StationId,
                    access.CanonicalStationId,
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
            // Incomplete or unavailable authorization state is never an allow.
            return false;
        }
    }
}

public interface IMetraActorAuthorizationContextProvider
{
    Task<bool> CanPerformOnResourceAsync(
        string actorSubject,
        string permission,
        MetraResourceDescriptor resource,
        CancellationToken cancellationToken);
}

public sealed class DenyAllMetraActorAuthorizationContextProvider
    : IMetraActorAuthorizationContextProvider
{
    public Task<bool> CanPerformOnResourceAsync(
        string actorSubject,
        string permission,
        MetraResourceDescriptor resource,
        CancellationToken cancellationToken)
        => Task.FromResult(false);
}

public sealed class MetraCombinedAuthorizationRequirement : Microsoft.AspNetCore.Authorization.IAuthorizationRequirement
{
    public string Permission => MetraPermissions.DailyObservationCreate;
}

public sealed class MetraCombinedAuthorizationHandler(
    IMetraActorAuthorizationContextProvider contextProvider)
    : Microsoft.AspNetCore.Authorization.AuthorizationHandler<
        MetraCombinedAuthorizationRequirement,
        MetraResourceDescriptor>
{
    protected override async Task HandleRequirementAsync(
        Microsoft.AspNetCore.Authorization.AuthorizationHandlerContext context,
        MetraCombinedAuthorizationRequirement requirement,
        MetraResourceDescriptor resource)
    {
        if (context.User.Identity?.IsAuthenticated != true ||
            string.IsNullOrWhiteSpace(resource.ResourceType) ||
            string.IsNullOrWhiteSpace(resource.ResourceId) ||
            (resource.StationId is not null && string.IsNullOrWhiteSpace(resource.StationId)))
        {
            return;
        }

        var subject = context.User.FindFirst("sub")?.Value;
        if (string.IsNullOrWhiteSpace(subject))
        {
            subject = context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        }

        if (string.IsNullOrWhiteSpace(subject))
        {
            return;
        }

        var cancellationToken = (context.Resource as Microsoft.AspNetCore.Http.HttpContext)?.RequestAborted
            ?? CancellationToken.None;

        if (await contextProvider.CanPerformOnResourceAsync(
            subject, requirement.Permission, resource, cancellationToken))
        {
            context.Succeed(requirement);
        }
    }
}

public static class MetraActorAuthorizationServiceCollectionExtensions
{
    public static IServiceCollection AddMetraActorAuthorizationContext(
        this IServiceCollection services)
    {
        Microsoft.Extensions.DependencyInjection.Extensions.ServiceCollectionDescriptorExtensions
            .TryAddScoped<IMetraActorAuthorizationContextProvider, DenyAllMetraActorAuthorizationContextProvider>();
        services.AddScoped<Microsoft.AspNetCore.Authorization.IAuthorizationHandler, MetraCombinedAuthorizationHandler>();
        return services;
    }
}
