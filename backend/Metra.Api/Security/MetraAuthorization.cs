using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;

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
/// This claim type is reserved for permissions resolved by trusted server-side
/// code from authoritative METRA grants. Never copy arbitrary client-supplied
/// values or unreviewed identity-provider role claims into this claim.
/// </summary>
public sealed class MetraPermissionRequirement(string permission) : IAuthorizationRequirement
{
    public string Permission { get; } = permission;
}

public sealed class MetraPermissionAuthorizationHandler
    : AuthorizationHandler<MetraPermissionRequirement>
{
    public const string PermissionClaimType = "metra_permission";
    public const string PermissionClaimIssuer = "urn:metra:internal:permissions";

    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        MetraPermissionRequirement requirement)
    {
        var hasPermission = context.User.Claims.Any(claim =>
            string.Equals(claim.Type, PermissionClaimType, StringComparison.Ordinal) &&
            string.Equals(claim.Issuer, PermissionClaimIssuer, StringComparison.Ordinal) &&
            string.Equals(claim.Value, requirement.Permission, StringComparison.Ordinal));

        if (hasPermission)
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}

public static class MetraAuthorizationServiceCollectionExtensions
{
    public static IServiceCollection AddMetraAuthorization(this IServiceCollection services)
    {
        services.AddSingleton<IAuthorizationHandler, MetraPermissionAuthorizationHandler>();
        services.AddAuthorization(options =>
        {
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
