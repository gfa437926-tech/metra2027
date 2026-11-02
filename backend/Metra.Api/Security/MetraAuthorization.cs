using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Metra.Api.Security;

/// <summary>
/// Canonical application permissions. These values are server-side authorization
/// identifiers, not display labels and not client-controlled role names.
/// </summary>
public static class MetraPermissions
{
    public const string RegistrationStationApprove = "registrations.station.approve";
    public const string RegistrationSystemApprove = "registrations.system.approve";
    public const string DailyObservationCreate = "observations.daily.create";

    public static IReadOnlyList<string> All { get; } = Array.AsReadOnly(
    [
        RegistrationStationApprove,
        RegistrationSystemApprove,
        DailyObservationCreate
    ]);
}

public static class MetraAuthorizationPolicies
{
    public const string PermissionPolicyPrefix = "permission:";
    public const string DailyObservationCreateInStation = "metra:daily-observation-create-in-station";

    public static string ForPermission(string permission)
    {
        if (string.IsNullOrWhiteSpace(permission) ||
            !MetraPermissions.All.Contains(permission, StringComparer.Ordinal))
        {
            throw new ArgumentException(
                "The permission is not part of the approved METRA permission catalogue.",
                nameof(permission));
        }

        return $"{PermissionPolicyPrefix}{permission}";
    }
}

/// <summary>
/// Resolves the current permission grant for an authenticated actor.
/// Implementations must read authoritative server-side grants, not token roles
/// or client-provided claims.
/// </summary>
public interface IMetraPermissionGrantEvaluator
{
    Task<bool> HasPermissionAsync(
        string actorSubject,
        string permission,
        CancellationToken cancellationToken);
}

/// <summary>
/// Safe bootstrap implementation: no action permission is granted until an
/// authoritative permission source is explicitly configured.
/// </summary>
public sealed class DenyAllMetraPermissionGrantEvaluator : IMetraPermissionGrantEvaluator
{
    public Task<bool> HasPermissionAsync(
        string actorSubject,
        string permission,
        CancellationToken cancellationToken)
        => Task.FromResult(false);
}

public sealed class MetraPermissionRequirement(string permission) : IAuthorizationRequirement
{
    public string Permission { get; } = permission;
}

public sealed class MetraPermissionAuthorizationHandler(
    IMetraPermissionGrantEvaluator evaluator)
    : AuthorizationHandler<MetraPermissionRequirement>
{
    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        MetraPermissionRequirement requirement)
    {
        if (context.User.Identity?.IsAuthenticated != true ||
            !MetraPermissions.All.Contains(requirement.Permission, StringComparer.Ordinal))
        {
            return;
        }

        // The subject comes only from the validated server authentication principal.
        // Never accept it from route values, request bodies, query strings or headers.
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

        if (await evaluator.HasPermissionAsync(
            subject, requirement.Permission, cancellationToken))
        {
            context.Succeed(requirement);
        }
    }
}

public static class MetraAuthorizationServiceCollectionExtensions
{
    public static IServiceCollection AddMetraAuthorization(this IServiceCollection services)
    {
        services.TryAddScoped<
            IMetraPermissionGrantEvaluator,
            DenyAllMetraPermissionGrantEvaluator>();
        services.AddScoped<IAuthorizationHandler, MetraPermissionAuthorizationHandler>();
        services.AddMetraActorAuthorizationContext();
        services.AddAuthorization(options =>
        {
            options.AddPolicy(
                MetraAuthorizationPolicies.DailyObservationCreateInStation,
                policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.AddRequirements(new MetraCombinedAuthorizationRequirement());
                });

            foreach (var permission in MetraPermissions.All)
            {
                options.AddPolicy(
                    MetraAuthorizationPolicies.ForPermission(permission),
                    policy =>
                    {
                        policy.RequireAuthenticatedUser();
                        policy.AddRequirements(new MetraPermissionRequirement(permission));
                    });
            }
        });

        return services;
    }
}
