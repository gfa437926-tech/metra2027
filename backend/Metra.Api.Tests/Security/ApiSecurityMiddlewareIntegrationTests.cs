using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
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
    public async Task Production_https_response_includes_hsts_header()
    {
        using var factory = new ApiFactory("Production");
        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://metra.example.test")
        });

        using var response = await client.GetAsync("/api/v1/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(response.Headers.TryGetValues("Strict-Transport-Security", out var hstsValues));
        Assert.Contains("max-age=", hstsValues!.Single());
    }

    [Fact]
    public async Task Cors_allows_only_configured_origin_for_simple_requests()
    {
        using var factory = new ApiFactory();
        Assert.Equal("https://metra.example.test",
            factory.Services.GetRequiredService<IConfiguration>()["Cors:AllowedOrigins:0"]);

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
    public async Task Cors_preflight_allows_configured_origin_and_requested_method()
    {
        using var factory = new ApiFactory();
        using var client = factory.CreateClient();

        using var request = new HttpRequestMessage(HttpMethod.Options, "/api/v1/health");
        request.Headers.Add("Origin", "https://metra.example.test");
        request.Headers.Add("Access-Control-Request-Method", "GET");
        using var response = await client.SendAsync(request);

        Assert.True(
            response.Headers.TryGetValues("Access-Control-Allow-Origin", out var origins),
            $"Expected CORS preflight allow-origin header. Status: {(int)response.StatusCode}; response: {await response.Content.ReadAsStringAsync()}");
        Assert.Equal("https://metra.example.test", origins!.Single());
        Assert.True(response.Headers.TryGetValues("Access-Control-Allow-Methods", out var methods));
        Assert.Contains("GET", methods!.Single());
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

    private sealed class ApiFactory(string environment = "Development") : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment(environment);
            builder.UseSetting("Cors:AllowedOrigins:0", "https://metra.example.test");
        }
    }
}
