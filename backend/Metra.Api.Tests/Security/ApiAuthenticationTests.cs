using System.Net;
using System.Text;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class ApiAuthenticationTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ApiAuthenticationTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Health_endpoint_is_anonymous()
    {
        using var response = await _client.GetAsync("/api/v1/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [InlineData("/api/v1/observations/daily/validate")]
    [InlineData("/api/v1/observations/hourly/validate")]
    [InlineData("/api/v1/observations/phenomena/validate")]
    [InlineData("/api/v1/stations")]
    [InlineData("/api/v1/stations?limit=500&offset=0")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/observations")]
    public async Task Every_observation_endpoint_requires_authentication(string path)
    {
        using var content = new StringContent("{}", Encoding.UTF8, "application/json");
        using var response = await _client.PostAsync(path, content);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData("/api/v1/observations/daily/validate")]
    [InlineData("/api/v1/observations/hourly/validate")]
    [InlineData("/api/v1/observations/phenomena/validate")]
    [InlineData("/api/v1/stations")]
    public async Task Malformed_bearer_token_is_rejected_for_observation_endpoints(string path)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, path);
        request.Headers.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", "not-a-jwt");
        request.Content = new StringContent("{}", Encoding.UTF8, "application/json");

        using var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
