using System.Security.Claims;
using Metra.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Infrastructure;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Xunit;

namespace Metra.Api.Tests;

public sealed class MetraAuthenticationBoundaryTests
{
    [Fact]
    public async Task Fallback_policy_rejects_anonymous_principals()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddMetraAuthenticationBoundary();
        services.AddMetraAuthorization();
        using var provider = services.BuildServiceProvider();

        var fallback = provider.GetRequiredService<IOptions<AuthorizationOptions>>()
            .Value.FallbackPolicy;
        Assert.NotNull(fallback);
        Assert.Contains(fallback!.Requirements, requirement =>
            requirement.GetType().Name == nameof(DenyAnonymousAuthorizationRequirement));

        var authorization = provider.GetRequiredService<IAuthorizationService>();
        var anonymous = new ClaimsPrincipal(new ClaimsIdentity());
        var result = await authorization.AuthorizeAsync(
            anonymous, resource: null, fallback.Requirements);

        Assert.False(result.Succeeded);
    }

    [Fact]
    public async Task Fallback_policy_accepts_only_an_authenticated_principal_at_the_authentication_layer()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddMetraAuthenticationBoundary();
        services.AddMetraAuthorization();
        using var provider = services.BuildServiceProvider();

        var fallback = provider.GetRequiredService<IOptions<AuthorizationOptions>>()
            .Value.FallbackPolicy!;
        var authorization = provider.GetRequiredService<IAuthorizationService>();
        var authenticated = new ClaimsPrincipal(
            new ClaimsIdentity([new Claim("sub", "test-subject")], authenticationType: "test"));

        var result = await authorization.AuthorizeAsync(
            authenticated, resource: null, fallback.Requirements);

        Assert.True(result.Succeeded);
    }

    [Fact]
    public void Unconfigured_authentication_scheme_is_the_default_and_does_not_issue_identity()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddMetraAuthenticationBoundary();
        using var provider = services.BuildServiceProvider();

        var options = provider.GetRequiredService<IOptions<AuthenticationOptions>>().Value;
        Assert.Equal(MetraAuthenticationDefaults.UnconfiguredScheme, options.DefaultAuthenticateScheme);
        Assert.Equal(MetraAuthenticationDefaults.UnconfiguredScheme, options.DefaultChallengeScheme);
        Assert.Equal(MetraAuthenticationDefaults.UnconfiguredScheme, options.DefaultForbidScheme);
    }
}
