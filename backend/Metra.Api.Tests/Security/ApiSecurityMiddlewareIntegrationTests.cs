using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Metra.Api.Tests;

public sealed class ApiSecurityMiddlewareIntegrationTests
{
    [Fact]
    public async Task Health_response_contains_security_headers()
    {
        using var factory = new ApiFactory();
        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/api/v1/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("nosniff", response.Headers.GetValues("X-Content-Type-Options").Single());
        Assert.Equal("DENY", response.Headers.GetValues("X-Frame-Options").Single());
        Assert.Equal("no-referrer", response.Headers.GetValues("Referrer-Policy").Single());
        Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
        Assert.Equal("no-cache", response.Headers.Pragma?.ToString());
        Assert.Contains("camera=()", response.Headers.GetValues("Permissions-Policy").Single());
    }

    [Fact]
    public async Task Cors_preflight_allows_only_configured_origin()
    {
        using var factory = new ApiFactory();
        using var client = factory.CreateClient();

        using var allowedRequest = new HttpRequestMessage(HttpMethod.Get, "/api/v1/health");
        allowedRequest.Headers.Add("Origin", "https://metra.example.test");
        using var allowedResponse = await client.SendAsync(allowedRequest);

        Assert.True(
            allowedResponse.Headers.TryGetValues("Access-Control-Allow-Origin", out var allowedOrigins),
            $"Expected CORS allow-origin header. Status: {(int)allowedResponse.StatusCode}; response: {await allowedResponse.Content.ReadAsStringAsync()}");
        Assert.Equal("https://metra.example.test", allowedOrigins!.Single());

        using var deniedRequest = new HttpRequestMessage(HttpMethod.Get, "/api/v1/health");
        deniedRequest.Headers.Add("Origin", "https://attacker.example.test");
        using var deniedResponse = await client.SendAsync(deniedRequest);

        Assert.False(deniedResponse.Headers.Contains("Access-Control-Allow-Origin"));
    }

    [Fact]
    public async Task Global_rate_limiter_rejects_requests_after_limit()
    {
        using var factory = new ApiFactory();
        using var client = factory.CreateClient();

        HttpResponseMessage? lastResponse = null;
        for (var i = 0; i < 121; i++)
        {
            lastResponse?.Dispose();
            lastResponse = await client.GetAsync("/api/v1/health");
        }

        using (lastResponse)
        {
            Assert.Equal((HttpStatusCode)429, lastResponse!.StatusCode);
        }
    }

    private sealed class ApiFactory : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Development");
            builder.ConfigureAppConfiguration((_, configuration) =>
            {
                configuration.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Cors:AllowedOrigins:0"] = "https://metra.example.test"
                });
            });
        }
    }
}
