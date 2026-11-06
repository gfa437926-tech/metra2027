using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Metra.Api.Tests;

public sealed class ApiSecurityHeadersAndAuthorizationTests
{
    [Fact]
    public async Task Api_responses_include_defensive_security_headers()
    {
        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder => builder.UseEnvironment("Development"));
        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });

        using var response = await client.GetAsync("/api/v1/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        AssertHeader(response, "X-Content-Type-Options", "nosniff");
        AssertHeader(response, "X-Frame-Options", "DENY");
        AssertHeader(response, "Referrer-Policy", "no-referrer");
        AssertHeader(response, "Permissions-Policy", "camera=(), microphone=(), geolocation=()");
        AssertHeader(response, "Cache-Control", "no-store");
        AssertHeader(response, "Pragma", "no-cache");
    }

    [Fact]
    public async Task Unauthenticated_requests_to_protected_station_directory_are_rejected()
    {
        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder => builder.UseEnvironment("Development"));
        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });

        using var response = await client.GetAsync("/api/v1/stations");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        AssertHeader(response, "Cache-Control", "no-store");
        AssertHeader(response, "X-Content-Type-Options", "nosniff");
    }

    [Fact]
    public async Task Observation_submission_endpoint_requires_authentication()
    {
        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder => builder.UseEnvironment("Development"));
        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });

        using var response = await client.PostAsync(
            $"/api/v1/stations/{Guid.NewGuid()}/observations",
            new StringContent("{}"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        AssertHeader(response, "Cache-Control", "no-store");
    }

    [Fact]
    public async Task Hsts_is_added_to_production_https_responses()
    {
        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder => builder.UseEnvironment("Production"));
        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost"),
            AllowAutoRedirect = false
        });

        using var response = await client.GetAsync("/api/v1/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(response.Headers.TryGetValues("Strict-Transport-Security", out var values));
        Assert.Contains(values!, value => value.Contains("max-age=", StringComparison.OrdinalIgnoreCase));
    }

    private static void AssertHeader(HttpResponseMessage response, string name, string expected)
    {
        Assert.True(response.Headers.TryGetValues(name, out var values), $"Missing response header: {name}");
        Assert.Contains(expected, values!);
    }
}
