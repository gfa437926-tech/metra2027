using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Metra.Api.Tests.Infrastructure;

/// <summary>
/// Deterministic auth for WebApplicationFactory tests. Not used in production.
/// Set HttpContext item or header X-Test-User-Id to control the subject claim.
/// </summary>
public sealed class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "Test";
    public const string DefaultUserId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

    public TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder) : base(options, logger, encoder)
    {
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.ContainsKey("Authorization"))
            return Task.FromResult(AuthenticateResult.NoResult());

        var userId = DefaultUserId;
        if (Request.Headers.TryGetValue("X-Test-User-Id", out var overrideId) &&
            !string.IsNullOrWhiteSpace(overrideId))
            userId = overrideId.ToString();

        var identity = new ClaimsIdentity(
            [new Claim("sub", userId)],
            SchemeName);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
