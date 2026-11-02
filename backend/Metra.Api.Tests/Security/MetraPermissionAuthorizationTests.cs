using System.Security.Claims;
using Metra.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Metra.Api.Tests;

public sealed class MetraPermissionAuthorizationTests
{
    [Fact]
    public async Task Grants_permission_only_for_exact_server_permission_claim()
    {
        var principal = Principal(
            new Claim(MetraPermissionAuthorizationHandler.PermissionClaimType,
                MetraPermissions.RegistrationStationApprove));
        var context = Context(principal, MetraPermissions.RegistrationStationApprove);

        await new MetraPermissionAuthorizationHandler().HandleAsync(context);

        Assert.True(context.HasSucceeded);
    }

    [Theory]
    [InlineData("registrations.system.approve")]
    [InlineData("registrations.station.approve.extra")]
    [InlineData("REGISTRATIONS.STATION.APPROVE")]
    [InlineData("admin")]
    public async Task Denies_missing_or_non_exact_permission_claim(string claimValue)
    {
        var principal = Principal(
            new Claim(MetraPermissionAuthorizationHandler.PermissionClaimType, claimValue));
        var context = Context(principal, MetraPermissions.RegistrationStationApprove);

        await new MetraPermissionAuthorizationHandler().HandleAsync(context);

        Assert.False(context.HasSucceeded);
        Assert.Single(context.PendingRequirements);
    }

    [Fact]
    public async Task Denies_permission_when_only_role_claim_is_present()
    {
        var principal = Principal(new Claim(ClaimTypes.Role, "StationManager"));
        var context = Context(principal, MetraPermissions.RegistrationStationApprove);

        await new MetraPermissionAuthorizationHandler().HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }

    [Fact]
    public async Task Denies_permission_when_permission_claim_type_is_not_exact()
    {
        var principal = Principal(new Claim("permission",
            MetraPermissions.RegistrationStationApprove));
        var context = Context(principal, MetraPermissions.RegistrationStationApprove);

        await new MetraPermissionAuthorizationHandler().HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }

    [Fact]
    public async Task Registered_permission_policies_require_authenticated_user_and_exact_permission()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddMetraAuthorization();
        using var provider = services.BuildServiceProvider();

        var policyProvider = provider.GetRequiredService<IAuthorizationPolicyProvider>();
        var policy = await policyProvider.GetPolicyAsync(
            MetraAuthorizationPolicies.ForPermission(MetraPermissions.RegistrationSystemApprove));

        Assert.NotNull(policy);
        Assert.Contains(policy!.Requirements, requirement =>
            requirement.GetType().Name == "DenyAnonymousAuthorizationRequirement");
        Assert.Contains(policy.Requirements, requirement =>
            requirement is MetraPermissionRequirement permission &&
            permission.Permission == MetraPermissions.RegistrationSystemApprove);
    }

    [Theory]
    [InlineData("")]
    [InlineData("unknown.permission")]
    [InlineData("admin")]
    public void Rejects_permission_policy_names_outside_approved_catalogue(string permission)
    {
        Assert.Throws<ArgumentException>(
            () => MetraAuthorizationPolicies.ForPermission(permission));
    }

    private static ClaimsPrincipal Principal(params Claim[] claims)
        => new(new ClaimsIdentity(claims, authenticationType: "test"));

    private static AuthorizationHandlerContext Context(
        ClaimsPrincipal principal,
        string permission)
        => new(
            [new MetraPermissionRequirement(permission)],
            principal,
            resource: null);
}
