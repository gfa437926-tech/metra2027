using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class SecurityRegressionTests
{
    [Fact]
    public async Task Health_response_includes_security_headers()
    {
        await using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(b =>
        {
            b.UseSetting("RateLimiting:Disabled", "true");
        });
        using var client = factory.CreateClient();
        using var response = await client.GetAsync("/api/v1/health");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("nosniff", response.Headers.GetValues("X-Content-Type-Options"));
        Assert.Contains("DENY", response.Headers.GetValues("X-Frame-Options"));
    }

    [Fact]
    public async Task Health_rate_limit_returns_429_after_burst()
    {
        await using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();
        HttpStatusCode? limited = null;
        for (var i = 0; i < 65; i++)
        {
            using var response = await client.GetAsync("/api/v1/health");
            if (response.StatusCode == HttpStatusCode.TooManyRequests)
            {
                limited = response.StatusCode;
                var body = await response.Content.ReadAsStringAsync();
                Assert.Contains("rate_limit_exceeded", body, StringComparison.Ordinal);
                Assert.DoesNotContain("Exception", body, StringComparison.OrdinalIgnoreCase);
                break;
            }
        }

        Assert.Equal(HttpStatusCode.TooManyRequests, limited);
    }

    [Fact]
    public async Task Protected_route_without_token_is_unauthorized_not_500()
    {
        await using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(b =>
        {
            b.UseSetting("RateLimiting:Disabled", "true");
        });
        using var client = factory.CreateClient();
        using var response = await client.GetAsync(
            "/api/v1/stations/11111111-1111-1111-1111-111111111111/observation-archive");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
