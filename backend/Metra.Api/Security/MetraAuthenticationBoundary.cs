using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Options;

namespace Metra.Api.Security;

/// <summary>
/// Placeholder authentication scheme used until an identity provider is approved.
/// It never authenticates a request; it exists to make the API fail closed with
/// a normal 401 challenge rather than silently running without an auth scheme.
/// Replace this registration with the approved OIDC/JWT adapter before launch.
/// </summary>
public sealed class UnconfiguredAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        => Task.FromResult(AuthenticateResult.NoResult());
}

public static class MetraAuthenticationDefaults
{
    public const string UnconfiguredScheme = "Metra.Unconfigured";
}

public static class MetraAuthenticationServiceCollectionExtensions
{
    public static IServiceCollection AddMetraAuthenticationBoundary(
        this IServiceCollection services)
    {
        services.AddAuthentication(options =>
        {
            options.DefaultAuthenticateScheme = MetraAuthenticationDefaults.UnconfiguredScheme;
            options.DefaultChallengeScheme = MetraAuthenticationDefaults.UnconfiguredScheme;
            options.DefaultForbidScheme = MetraAuthenticationDefaults.UnconfiguredScheme;
        }).AddScheme<AuthenticationSchemeOptions, UnconfiguredAuthenticationHandler>(
            MetraAuthenticationDefaults.UnconfiguredScheme,
            _ => { });

        return services;
    }
}
