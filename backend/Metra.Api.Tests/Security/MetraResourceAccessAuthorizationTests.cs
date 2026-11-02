using System.Security.Claims;
using Metra.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class MetraResourceAccessAuthorizationTests
{
    private static readonly MetraResourceDescriptor Resource =
        new("observation", "obs-100", "station-7");

    [Fact]
    public async Task Allows_resource_only_when_authoritative_evaluator_grants_access()
    {
        var evaluator = new FakeEvaluator(true);
        var context = CreateContext(AuthenticatedPrincipal("user-42"), Resource);

        await new MetraResourceAccessHandler(evaluator).HandleAsync(context);

        Assert.True(context.HasSucceeded);
        Assert.Equal("user-42", evaluator.ActorSubject);
        Assert.Equal(Resource, evaluator.Resource);
    }

    [Fact]
    public async Task Denies_cross_station_resource_when_evaluator_rejects_access()
    {
        var evaluator = new FakeEvaluator(false);
        var context = CreateContext(AuthenticatedPrincipal("user-42"), Resource);

        await new MetraResourceAccessHandler(evaluator).HandleAsync(context);

        Assert.False(context.HasSucceeded);
        Assert.Equal("user-42", evaluator.ActorSubject);
    }

    [Fact]
    public async Task Does_not_call_evaluator_for_anonymous_principal()
    {
        var evaluator = new FakeEvaluator(true);
        var context = CreateContext(new ClaimsPrincipal(new ClaimsIdentity()), Resource);

        await new MetraResourceAccessHandler(evaluator).HandleAsync(context);

        Assert.False(context.HasSucceeded);
        Assert.Null(evaluator.ActorSubject);
    }

    [Fact]
    public async Task Denies_authenticated_principal_without_stable_subject()
    {
        var evaluator = new FakeEvaluator(true);
        var principal = new ClaimsPrincipal(
            new ClaimsIdentity([new Claim(ClaimTypes.Name, "display-name")], "test"));
        var context = CreateContext(principal, Resource);

        await new MetraResourceAccessHandler(evaluator).HandleAsync(context);

        Assert.False(context.HasSucceeded);
        Assert.Null(evaluator.ActorSubject);
    }

    [Theory]
    [InlineData("", "obs-100", "station-7")]
    [InlineData("observation", "", "station-7")]
    [InlineData("observation", "obs-100", " ")]
    public async Task Denies_malformed_resource_descriptor(
        string resourceType,
        string resourceId,
        string stationId)
    {
        var evaluator = new FakeEvaluator(true);
        var context = CreateContext(
            AuthenticatedPrincipal("user-42"),
            new MetraResourceDescriptor(resourceType, resourceId, stationId));

        await new MetraResourceAccessHandler(evaluator).HandleAsync(context);

        Assert.False(context.HasSucceeded);
        Assert.Null(evaluator.ActorSubject);
    }

    [Fact]
    public async Task Resource_access_policy_requires_authenticated_user_and_resource_requirement()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddAuthorization();
        services.AddMetraResourceAuthorization();
        using var provider = services.BuildServiceProvider();

        var providerForPolicies = provider.GetRequiredService<IAuthorizationPolicyProvider>();
        var policy = await providerForPolicies.GetPolicyAsync(
            MetraResourceAuthorizationPolicies.ResourceAccess);

        Assert.NotNull(policy);
        Assert.Contains(policy!.Requirements, item =>
            item.GetType().Name == "DenyAnonymousAuthorizationRequirement");
        Assert.Contains(policy.Requirements, item =>
            item is MetraResourceAccessRequirement);
    }

    private static ClaimsPrincipal AuthenticatedPrincipal(string subject)
        => new(new ClaimsIdentity([new Claim("sub", subject)], "validated-test"));

    private static AuthorizationHandlerContext CreateContext(
        ClaimsPrincipal principal,
        MetraResourceDescriptor resource)
        => new(
            [new MetraResourceAccessRequirement()],
            principal,
            resource);

    private sealed class FakeEvaluator(bool decision) : IMetraResourceAccessEvaluator
    {
        public string? ActorSubject { get; private set; }
        public MetraResourceDescriptor? Resource { get; private set; }

        public Task<bool> CanAccessAsync(
            string actorSubject,
            MetraResourceDescriptor resource,
            CancellationToken cancellationToken)
        {
            ActorSubject = actorSubject;
            Resource = resource;
            return Task.FromResult(decision);
        }
    }
}
