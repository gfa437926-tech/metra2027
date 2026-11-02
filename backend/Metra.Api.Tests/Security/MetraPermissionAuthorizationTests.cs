using System.Security.Claims;
using Metra.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Metra.Api.Tests;

public sealed class MetraPermissionAuthorizationTests
{
    [Fact]
    public async Task Grants_permission_only_when_authoritative_evaluator_allows()
    {
        var evaluator = new FakePermissionEvaluator(true);
        var context = Context(Principal(new Claim("sub", "subject-42")),
            MetraPermissions.RegistrationStationApprove);
        await new MetraPermissionAuthorizationHandler(evaluator).HandleAsync(context);

        Assert.True(context.HasSucceeded);
        Assert.Equal("subject-42", evaluator.ActorSubject);
        Assert.Equal(MetraPermissions.RegistrationStationApprove, evaluator.Permission);
    }

    [Fact]
    public async Task Denies_permission_when_authoritative_evaluator_denies()
    {
        var context = Context(Principal(new Claim("sub", "subject-42")),
            MetraPermissions.RegistrationStationApprove);

        await new MetraPermissionAuthorizationHandler(new FakePermissionEvaluator(false))
            .HandleAsync(context);

        Assert.False(context.HasSucceeded);
    }

    [Fact]
    public async Task Denies_permission_when_only_external_role_or_permission_claims_exist()
    {
        var principal = Principal(
            new Claim(ClaimTypes.Role, "StationManager"),
            new Claim("metra_permission", MetraPermissions.RegistrationStationApprove));

        await new MetraPermissionAuthorizationHandler(new FakePermissionEvaluator(false))
            .HandleAsync(Context(principal, MetraPermissions.RegistrationStationApprove));

        Assert.False(Context(principal, MetraPermissions.RegistrationStationApprove).HasSucceeded);
    }

    [Fact]
    public async Task Denies_permission_when_authenticated_subject_is_missing()
    {
        var evaluator = new FakePermissionEvaluator(true);
        var context = Context(Principal(new Claim(ClaimTypes.Name, "display-name")),
            MetraPermissions.RegistrationStationApprove);

        await new MetraPermissionAuthorizationHandler(evaluator).HandleAsync(context);

        Assert.False(context.HasSucceeded);
        Assert.Null(evaluator.ActorSubject);
    }

    [Fact]
    public async Task Uses_name_identifier_as_subject_fallback()
    {
        var evaluator = new FakePermissionEvaluator(true);
        var context = Context(Principal(new Claim(ClaimTypes.NameIdentifier, "subject-fallback")),
            MetraPermissions.DailyObservationCreate);

        await new MetraPermissionAuthorizationHandler(evaluator).HandleAsync(context);

        Assert.True(context.HasSucceeded);
        Assert.Equal("subject-fallback", evaluator.ActorSubject);
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
        Assert.IsType<DenyAllMetraPermissionGrantEvaluator>(
            provider.GetRequiredService<IMetraPermissionGrantEvaluator>());
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
        => new([new MetraPermissionRequirement(permission)], principal, resource: null);

    private sealed class FakePermissionEvaluator(bool allowed) : IMetraPermissionGrantEvaluator
    {
        public string? ActorSubject { get; private set; }
        public string? Permission { get; private set; }

        public Task<bool> HasPermissionAsync(
            string actorSubject,
            string permission,
            CancellationToken cancellationToken)
        {
            ActorSubject = actorSubject;
            Permission = permission;
            return Task.FromResult(allowed);
        }
    }
}
