using System.Security.Claims;
using Metra.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class CombinedAuthorizationIntegrationTests
{
    [Fact]
    public async Task Allows_only_when_both_action_permission_and_resource_scope_are_granted()
    {
        using var provider = CreateProvider(permissionAllowed: true, resourceAllowed: true);
        var authorization = provider.GetRequiredService<IAuthorizationService>();

        var result = await authorization.AuthorizeAsync(
            Principal("subject-42"),
            new MetraResourceDescriptor("observation", "obs-100", "untrusted-station"),
            MetraAuthorizationPolicies.DailyObservationCreateInStation);

        Assert.True(result.Succeeded);
    }

    [Theory]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(false, false)]
    public async Task Denies_when_either_permission_or_resource_scope_is_missing(
        bool permissionAllowed,
        bool resourceAllowed)
    {
        using var provider = CreateProvider(permissionAllowed, resourceAllowed);
        var authorization = provider.GetRequiredService<IAuthorizationService>();

        var result = await authorization.AuthorizeAsync(
            Principal("subject-42"),
            new MetraResourceDescriptor("observation", "obs-100", "station-7"),
            MetraAuthorizationPolicies.DailyObservationCreateInStation);

        Assert.False(result.Succeeded);
    }

    [Fact]
    public async Task Denies_anonymous_actor_even_when_test_evaluators_would_allow()
    {
        using var provider = CreateProvider(permissionAllowed: true, resourceAllowed: true);
        var authorization = provider.GetRequiredService<IAuthorizationService>();

        var result = await authorization.AuthorizeAsync(
            new ClaimsPrincipal(new ClaimsIdentity()),
            new MetraResourceDescriptor("observation", "obs-100"),
            MetraAuthorizationPolicies.DailyObservationCreateInStation);

        Assert.False(result.Succeeded);
    }

    [Fact]
    public async Task Combined_policy_contains_both_independent_requirements()
    {
        using var provider = CreateProvider(permissionAllowed: true, resourceAllowed: true);
        var policyProvider = provider.GetRequiredService<IAuthorizationPolicyProvider>();

        var policy = await policyProvider.GetPolicyAsync(
            MetraAuthorizationPolicies.DailyObservationCreateInStation);

        Assert.NotNull(policy);
        Assert.Contains(policy!.Requirements, requirement =>
            requirement is MetraPermissionRequirement permission &&
            permission.Permission == MetraPermissions.DailyObservationCreate);
        Assert.Contains(policy.Requirements, requirement =>
            requirement is MetraResourceAccessRequirement);
    }

    private static ServiceProvider CreateProvider(bool permissionAllowed, bool resourceAllowed)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddMetraAuthorization();
        services.AddMetraResourceAuthorization();
        services.AddSingleton<IMetraPermissionGrantEvaluator>(
            new FixedPermissionEvaluator(permissionAllowed));
        services.AddSingleton<IMetraResourceAccessEvaluator>(
            new FixedResourceEvaluator(resourceAllowed));
        return services.BuildServiceProvider(validateScopes: true);
    }

    private static ClaimsPrincipal Principal(string subject)
        => new(new ClaimsIdentity([new Claim("sub", subject)], "validated-test"));

    private sealed class FixedPermissionEvaluator(bool allowed) : IMetraPermissionGrantEvaluator
    {
        public Task<bool> HasPermissionAsync(
            string actorSubject,
            string permission,
            CancellationToken cancellationToken)
            => Task.FromResult(allowed);
    }

    private sealed class FixedResourceEvaluator(bool allowed) : IMetraResourceAccessEvaluator
    {
        public Task<bool> CanAccessAsync(
            string actorSubject,
            MetraResourceDescriptor resource,
            CancellationToken cancellationToken)
            => Task.FromResult(allowed);
    }
}
