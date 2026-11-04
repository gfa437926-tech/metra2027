using System.Net;
using System.Text;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class ApiAuthenticationTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    private readonly WebApplicationFactory<Program> _factory;

    public ApiAuthenticationTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Health_endpoint_is_anonymous()
    {
        using var response = await _client.GetAsync("/api/v1/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Readiness_endpoint_is_anonymous_but_fails_when_server_dependencies_are_missing()
    {
        using var response = await _client.GetAsync("/api/v1/ready");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    [Fact]
    public async Task Readiness_endpoint_fails_when_supabase_probe_cannot_be_completed_even_if_credentials_are_present()
    {
        using var configuredFactory = _factory.WithWebHostBuilder(builder =>
            builder.ConfigureAppConfiguration((_, configuration) =>
                configuration.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Supabase:Url"] = "https://tbdnklyxjvbrilvnwgmq.supabase.co",
                    ["Supabase:ServiceRoleKey"] = "test-only-placeholder"
                })));
        using var client = configuredFactory.CreateClient();

        using var response = await client.GetAsync("/api/v1/ready");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("test-only-placeholder", body, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("/api/v1/observations/daily/validate")]
    [InlineData("/api/v1/observations/hourly/validate")]
    [InlineData("/api/v1/observations/phenomena/validate")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/observations")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/observations/22222222-2222-2222-2222-222222222222/decision")]
    public async Task Every_observation_endpoint_requires_authentication(string path)
    {
        using var response = await SendUnauthenticated(path);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData("/api/v1/observations/daily/validate")]
    [InlineData("/api/v1/observations/hourly/validate")]
    [InlineData("/api/v1/observations/phenomena/validate")]
    [InlineData("/api/v1/stations")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/observations")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/observations/22222222-2222-2222-2222-222222222222/decision")]
    public async Task Malformed_bearer_token_is_rejected_for_observation_and_station_endpoints(string path)
    {
        using var request = new HttpRequestMessage(path.StartsWith("/api/v1/stations", StringComparison.Ordinal) && !path.EndsWith("/decision", StringComparison.Ordinal) ? HttpMethod.Get : HttpMethod.Post, path);
        request.Headers.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", "not-a-jwt");
        if (request.Method == HttpMethod.Post) request.Content = new StringContent("{}", Encoding.UTF8, "application/json");

        using var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData("/api/v1/stations")]
    [InlineData("/api/v1/stations?limit=500&offset=0")]
    public async Task Station_directory_requires_authentication(string path)
    {
        using var response = await _client.GetAsync(path);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private Task<HttpResponseMessage> SendUnauthenticated(string path)
    {
        if (path.StartsWith("/api/v1/stations", StringComparison.Ordinal) && !path.EndsWith("/decision", StringComparison.Ordinal))
            return _client.GetAsync(path);
        return _client.PostAsync(path, new StringContent("{}", Encoding.UTF8, "application/json"));
    }
}
