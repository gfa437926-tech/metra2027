using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Metra.Api.Tests.Security;

/// <summary>
/// HTTP pipeline contracts (status codes / headers) without live Supabase.
/// </summary>
public sealed class HttpPipelineContractTests
{
    private static WebApplicationFactory<Program> Factory(bool rateLimit = false) =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(b =>
        {
            if (!rateLimit)
                b.UseSetting("RateLimiting:Disabled", "true");
        });

    [Theory]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/observations")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/observation-queue")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/observation-archive")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/users")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/audit-log")]
    [InlineData("/api/v1/authorities/11111111-1111-1111-1111-111111111111/permission-grants")]
    public async Task Protected_routes_return_401_without_bearer(string path)
    {
        await using var factory = Factory();
        using var client = factory.CreateClient();
        using var response = path.Contains("permission-grants") || path.Contains("/observations") && !path.Contains("queue") && !path.Contains("archive")
            ? await client.PostAsync(path, new StringContent("{}", System.Text.Encoding.UTF8, "application/json"))
            : await client.GetAsync(path);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public void Production_rejects_disabled_rate_limiting()
    {
        using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(b =>
        {
            b.UseSetting("environment", "Production");
            b.UseSetting("RateLimiting:Disabled", "true");
        });

        var exception = Assert.ThrowsAny<Exception>(() => factory.CreateClient());
        Assert.Contains("Rate limiting cannot be disabled", exception.ToString(), StringComparison.Ordinal);
    }

    [Fact]
    public async Task Health_is_200_and_ready_is_503_when_deps_missing()
    {
        await using var factory = Factory();
        using var client = factory.CreateClient();
        using var health = await client.GetAsync("/api/v1/health");
        Assert.Equal(HttpStatusCode.OK, health.StatusCode);
        using var ready = await client.GetAsync("/api/v1/ready");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, ready.StatusCode);
    }

    [Fact]
    public async Task Malformed_bearer_does_not_return_500()
    {
        await using var factory = Factory();
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.TryAddWithoutValidation("Authorization", "Bearer not-a-jwt");
        using var response = await client.GetAsync(
            "/api/v1/stations/11111111-1111-1111-1111-111111111111/observation-archive");
        Assert.True(
            response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden,
            $"unexpected {(int)response.StatusCode}");
    }
}
