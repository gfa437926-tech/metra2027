using System.Net;
using System.Net.Http.Headers;
using Metra.Api.Tests.Infrastructure;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Metra.Api.Tests.Features.Stations;

/// <summary>
/// HTTP-level request-guard coverage for GET /api/v1/stations.
/// Invalid requests must be rejected before station-scope reads.
/// </summary>
public sealed class StationDirectoryEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public StationDirectoryEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Unauthenticated_directory_request_is_rejected()
    {
        using var client = CreateClient(authenticate: false);

        using var response = await client.GetAsync("/api/v1/stations");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData("?limit=0")]
    [InlineData("?limit=501")]
    [InlineData("?offset=-1")]
    public async Task Invalid_pagination_is_rejected(string query)
    {
        using var client = CreateClient();

        using var response = await client.GetAsync("/api/v1/stations" + query);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData("unknown")]
    [InlineData("CLASSIC")]
    [InlineData("")]
    public async Task Unsupported_station_type_is_rejected(string stationType)
    {
        using var client = CreateClient();

        using var response = await client.GetAsync(
            "/api/v1/stations?stationType=" + Uri.EscapeDataString(stationType));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    private HttpClient CreateClient(bool authenticate = true)
    {
        var factory = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureTestServices(services =>
            {
                services.AddAuthentication(options =>
                {
                    options.DefaultAuthenticateScheme = TestAuthHandler.SchemeName;
                    options.DefaultChallengeScheme = TestAuthHandler.SchemeName;
                }).AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                    TestAuthHandler.SchemeName, _ => { });
            });
        });

        var client = factory.CreateClient();
        if (authenticate)
            client.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", "test-token");
        return client;
    }
}
