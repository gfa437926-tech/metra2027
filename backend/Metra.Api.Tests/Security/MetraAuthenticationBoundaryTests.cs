using System.Security.Claims;
using Metra.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authorization.Infrastructure;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.TestHost;
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
    public async Task Unconfigured_scheme_challenges_unannotated_routes_with_401_but_allows_explicit_public_routes()
    {
        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseTestServer();
        builder.Services.AddMetraAuthenticationBoundary();
        builder.Services.AddMetraAuthorization();

        await using var app = builder.Build();
        app.UseAuthentication();
        app.UseAuthorization();
        app.MapGet("/protected-by-fallback", () => Results.Ok(new { status = "unexpected" }));
        app.MapGet("/public", () => Results.Ok(new { status = "public" })).AllowAnonymous();
        await app.StartAsync();

        using var client = app.GetTestClient();
        using var protectedResponse = await client.GetAsync("/protected-by-fallback");
        using var publicResponse = await client.GetAsync("/public");

        Assert.Equal(System.Net.HttpStatusCode.Unauthorized, protectedResponse.StatusCode);
        Assert.Equal(System.Net.HttpStatusCode.OK, publicResponse.StatusCode);
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
