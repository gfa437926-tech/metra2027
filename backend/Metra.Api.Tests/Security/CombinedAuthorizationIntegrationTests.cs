using System.Security.Claims;
using Metra.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class CombinedAuthorizationIntegrationTests
{
    [Fact]
    public async Task Allows_only_when_consistent_context_provider_grants_both_dimensions()
    {
        using var provider = CreateProvider(permissionAllowed: true, resourceAllowed: true);
        using var scope = provider.CreateScope();
        var authorization = scope.ServiceProvider.GetRequiredService<IAuthorizationService>();

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
        using var scope = provider.CreateScope();
        var authorization = scope.ServiceProvider.GetRequiredService<IAuthorizationService>();

        var result = await authorization.AuthorizeAsync(
            Principal("subject-42"),
            new MetraResourceDescriptor("observation", "obs-100", "station-7"),
            MetraAuthorizationPolicies.DailyObservationCreateInStation);

        Assert.False(result.Succeeded);
    }

    [Fact]
    public async Task Denies_anonymous_actor_even_when_context_provider_would_allow()
    {
        using var provider = CreateProvider(permissionAllowed: true, resourceAllowed: true);
        using var scope = provider.CreateScope();
        var authorization = scope.ServiceProvider.GetRequiredService<IAuthorizationService>();

        var result = await authorization.AuthorizeAsync(
            new ClaimsPrincipal(new ClaimsIdentity()),
            new MetraResourceDescriptor("observation", "obs-100"),
            MetraAuthorizationPolicies.DailyObservationCreateInStation);

        Assert.False(result.Succeeded);
    }

    [Fact]
    public async Task Combined_policy_uses_one_combined_requirement_not_independent_reads()
    {
        using var provider = CreateProvider(permissionAllowed: true, resourceAllowed: true);
        var policyProvider = provider.GetRequiredService<IAuthorizationPolicyProvider>();

        var policy = await policyProvider.GetPolicyAsync(
            MetraAuthorizationPolicies.DailyObservationCreateInStation);

        Assert.NotNull(policy);
        Assert.Single(policy!.Requirements);
        Assert.Contains(policy.Requirements, requirement =>
            requirement is MetraCombinedAuthorizationRequirement);
    }

    private static ServiceProvider CreateProvider(bool permissionAllowed, bool resourceAllowed)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddMetraAuthorization();
        services.AddMetraResourceAuthorization();
        services.AddSingleton<IMetraActorAuthorizationContextProvider>(
            new FixedContextProvider(permissionAllowed && resourceAllowed));
        return services.BuildServiceProvider(validateScopes: true);
    }

    private static ClaimsPrincipal Principal(string subject)
        => new(new ClaimsIdentity([new Claim("sub", subject)], "validated-test"));

    private sealed class FixedContextProvider(bool allowed) : IMetraActorAuthorizationContextProvider
    {
        public Task<bool> CanPerformOnResourceAsync(
            string actorSubject,
            string permission,
            MetraResourceDescriptor resource,
            CancellationToken cancellationToken)
            => Task.FromResult(allowed);
    }
}
