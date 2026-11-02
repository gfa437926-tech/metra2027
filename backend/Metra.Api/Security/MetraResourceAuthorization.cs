using System.Security.Claims;
using Metra.Api.Security;
using Microsoft.AspNetCore.Authorization;

namespace Metra.Api.Security;

/// <summary>
/// A resource identifier supplied by the route/application layer. The evaluator
/// must verify the resource's actual station ownership from authoritative data;
/// it must not trust StationId merely because it appears in this descriptor.
/// </summary>
public sealed record MetraResourceDescriptor(
    string ResourceType,
    string ResourceId,
    string? StationId = null);

/// <summary>
/// Resolves object-level access using authoritative METRA resource and station
/// assignment data. Implementations must fail closed for missing/deleted resources,
/// unknown assignments, inactive actors and data-source failures.
/// </summary>
public interface IMetraResourceAccessEvaluator
{
    Task<bool> CanAccessAsync(
        string actorSubject,
        MetraResourceDescriptor resource,
        CancellationToken cancellationToken);
}

public sealed class MetraResourceAccessRequirement : IAuthorizationRequirement
{
}

public sealed class MetraResourceAccessHandler(
    IMetraResourceAccessEvaluator evaluator)
    : AuthorizationHandler<MetraResourceAccessRequirement, MetraResourceDescriptor>
{
    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        MetraResourceAccessRequirement requirement,
        MetraResourceDescriptor resource)
    {
        if (context.User.Identity?.IsAuthenticated != true ||
            string.IsNullOrWhiteSpace(resource.ResourceType) ||
            string.IsNullOrWhiteSpace(resource.ResourceId) ||
            (resource.StationId is not null && string.IsNullOrWhiteSpace(resource.StationId)))
        {
            return;
        }

        // The subject is read only from the authenticated ClaimsPrincipal created
        // by the configured authentication handler. Never accept it from a route,
        // request body, query string or custom header.
        var subject = context.User.FindFirst("sub")?.Value;
        if (string.IsNullOrWhiteSpace(subject))
        {
            subject = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        }

        if (string.IsNullOrWhiteSpace(subject))
        {
            return;
        }

        var cancellationToken = (context.Resource as HttpContext)?.RequestAborted
            ?? CancellationToken.None;

        if (await evaluator.CanAccessAsync(subject, resource, cancellationToken))
        {
            context.Succeed(requirement);
        }
    }
}

public static class MetraResourceAuthorizationPolicies
{
    public const string ResourceAccess = "metra:resource-access";
}

public static class MetraResourceAuthorizationServiceCollectionExtensions
{
    public static IServiceCollection AddMetraResourceAuthorization(
        this IServiceCollection services)
    {
        services.AddScoped<IAuthorizationHandler, MetraResourceAccessHandler>();
        services.AddAuthorization(options =>
        {
            options.AddPolicy(
                MetraResourceAuthorizationPolicies.ResourceAccess,
                policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.AddRequirements(new MetraResourceAccessRequirement());
                });
        });

        return services;
    }
}
