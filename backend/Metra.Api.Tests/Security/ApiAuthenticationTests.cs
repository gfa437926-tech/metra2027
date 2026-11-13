using System.Net;
using System.Text;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Metra.Api.Features.Stations;
using Metra.Api.Features.Users;
using System.Text.Json;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class ApiAuthenticationTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    private readonly WebApplicationFactory<Program> _factory;

    public ApiAuthenticationTests(WebApplicationFactory<Program> factory)
    {
        // Disable rate limiting for auth/readiness suite so sequential health probes do not 429.
        _factory = factory.WithWebHostBuilder(builder =>
            builder.UseSetting("RateLimiting:Disabled", "true"));
        _client = _factory.CreateClient();
    }

    [Fact]
    public void Every_supabase_dependency_client_has_a_bounded_timeout()
    {
        var clients = _factory.Services.GetRequiredService<IHttpClientFactory>();
        var names = new[]
        {
            "SupabaseStationAuthorizationService",
            "SupabaseObservationSubmissionService",
            "SupabaseObservationDecisionService",
            "SupabaseObservationQueueService",
            "SupabaseStationDirectoryService",
            "SupabaseStationCatalogueReviewService",
            "SupabaseRegistrationReviewService",
            "SupabaseRegistrationSubmissionService",
            "SupabaseStationUserDirectoryService",
            "SupabaseStationAuditService",
            "SupabaseStationAssignmentService",
            "SupabaseAuthorityAccessService"
        };

        foreach (var name in names)
            Assert.Equal(TimeSpan.FromSeconds(8), clients.CreateClient(name).Timeout);
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
    public async Task Readiness_endpoint_fails_when_supabase_probe_fails_even_if_credentials_are_present()
    {
        using var configuredFactory = CreateConfiguredReadinessFactory(stations: null);
        using var client = configuredFactory.CreateClient();

        using var response = await client.GetAsync("/api/v1/ready");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("test-only-placeholder", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Readiness_endpoint_fails_when_station_audit_service_is_not_configured()
    {
        using var configuredFactory = CreateConfiguredReadinessFactory(
            JsonDocument.Parse("[]").RootElement.Clone(), auditConfigured: false);
        using var client = configuredFactory.CreateClient();

        using var response = await client.GetAsync("/api/v1/ready");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    [Fact]
    public async Task Readiness_endpoint_succeeds_only_after_station_catalogue_probe_succeeds()
    {
        using var configuredFactory = CreateConfiguredReadinessFactory(JsonDocument.Parse("[]").RootElement.Clone());
        using var client = configuredFactory.CreateClient();

        using var response = await client.GetAsync("/api/v1/ready");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("\"status\":\"ready\"", body, StringComparison.Ordinal);
    }

    private WebApplicationFactory<Program> CreateConfiguredReadinessFactory(
        JsonElement? stations, bool auditConfigured = true)
    {
        return _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, configuration) =>
                configuration.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Supabase:Url"] = "https://tbdnklyxjvbrilvnwgmq.supabase.co",
                    ["Supabase:ServiceRoleKey"] = "test-only-placeholder"
                }));
            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<IStationDirectoryService>();
                services.AddSingleton<IStationDirectoryService>(
                    new ReadinessStationDirectoryStub(stations));
                services.RemoveAll<IStationAuditService>();
                services.AddSingleton<IStationAuditService>(
                    new ReadinessStationAuditStub(auditConfigured));
            });
        });
    }

    private sealed class ReadinessStationAuditStub(bool isConfigured) : IStationAuditService
    {
        public bool IsConfigured => isConfigured;

        public Task<JsonElement?> GetAuditAsync(
            Guid actorUserId, Guid stationId, int limit, CancellationToken cancellationToken) =>
            Task.FromResult<JsonElement?>(JsonDocument.Parse("[]").RootElement.Clone());
    }

    private sealed class ReadinessStationDirectoryStub(JsonElement? stations) : IStationDirectoryService
    {
        public bool IsConfigured => true;

        public Task<JsonElement?> GetStationsAsync(
            int limit, int offset, string? stationType, CancellationToken cancellationToken) =>
            Task.FromResult(stations);
    }

    [Theory]
    [InlineData("/api/v1/observations/daily/validate")]
    [InlineData("/api/v1/observations/hourly/validate")]
    [InlineData("/api/v1/observations/phenomena/validate")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/observations")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/observations/22222222-2222-2222-2222-222222222222/decision")]
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/audit-log")]
    public async Task Every_protected_station_endpoint_requires_authentication(string path)
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
    [InlineData("/api/v1/stations/11111111-1111-1111-1111-111111111111/audit-log")]
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

    [Theory]
    [InlineData("GET", "/api/v1/authorities")]
    [InlineData("GET", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/membership-roles")]
    [InlineData("GET", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/permission-options")]
    [InlineData("GET", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/access-queue?kind=membership")]
    [InlineData("GET", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/access-audit")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/memberships")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/memberships/22222222-2222-2222-2222-222222222222/decision")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/memberships/22222222-2222-2222-2222-222222222222/revocation")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/permission-grants")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/permission-grants/22222222-2222-2222-2222-222222222222/decision")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/permission-grants/22222222-2222-2222-2222-222222222222/revocation")]
    public async Task Every_authority_access_endpoint_requires_authentication(string method, string path)
    {
        using var request = new HttpRequestMessage(new HttpMethod(method), path);
        if (request.Method == HttpMethod.Post)
            request.Content = new StringContent("{}", Encoding.UTF8, "application/json");

        using var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData("GET", "/api/v1/authorities")]
    [InlineData("GET", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/membership-roles")]
    [InlineData("GET", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/permission-options")]
    [InlineData("GET", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/access-queue?kind=membership")]
    [InlineData("GET", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/access-audit")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/memberships")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/memberships/22222222-2222-2222-2222-222222222222/decision")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/memberships/22222222-2222-2222-2222-222222222222/revocation")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/permission-grants")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/permission-grants/22222222-2222-2222-2222-222222222222/decision")]
    [InlineData("POST", "/api/v1/authorities/11111111-1111-1111-1111-111111111111/permission-grants/22222222-2222-2222-2222-222222222222/revocation")]
    public async Task Malformed_bearer_token_is_rejected_for_authority_access_endpoints(string method, string path)
    {
        using var request = new HttpRequestMessage(new HttpMethod(method), path);
        request.Headers.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", "not-a-jwt");
        if (request.Method == HttpMethod.Post)
            request.Content = new StringContent("{}", Encoding.UTF8, "application/json");

        using var response = await _client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private Task<HttpResponseMessage> SendUnauthenticated(string path)
    {
        if (path.StartsWith("/api/v1/stations", StringComparison.Ordinal) && !path.EndsWith("/decision", StringComparison.Ordinal))
            return _client.GetAsync(path);
        return _client.PostAsync(path, new StringContent("{}", Encoding.UTF8, "application/json"));
    }
}
