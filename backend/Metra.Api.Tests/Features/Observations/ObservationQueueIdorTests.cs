using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using Metra.Api.Features.Observations;
using Metra.Api.Security;
using Metra.Api.Tests.Infrastructure;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

/// <summary>
/// IDOR / station isolation tests for the observation review queue.
/// </summary>
public sealed class ObservationQueueIdorTests : IClassFixture<WebApplicationFactory<Program>>
{
    private static readonly Guid StationId = Guid.Parse("11111111-1111-4111-8111-111111111111");
    private static readonly Guid OtherStationId = Guid.Parse("22222222-2222-4222-8222-222222222222");
    private static readonly Guid UserId = Guid.Parse(TestAuthHandler.DefaultUserId);

    private readonly WebApplicationFactory<Program> _factory;

    public ObservationQueueIdorTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Unauthenticated_queue_read_is_rejected()
    {
        using var client = _factory.CreateClient();
        using var response = await client.GetAsync($"/api/v1/stations/{StationId}/observations");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Authenticated_user_without_review_permission_is_forbidden()
    {
        var queue = new RecordingQueueService();
        using var client = CreateClient(allowReview: false, queue: queue);

        using var response = await client.GetAsync($"/api/v1/stations/{StationId}/observations");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Empty(queue.Calls);
    }

    [Fact]
    public async Task Permission_on_one_station_does_not_authorize_another_station()
    {
        var queue = new RecordingQueueService();
        var auth = new ConfigurableAuthorizationService();
        auth.Allowed[(UserId, StationId, "observation.review")] = true;

        using var client = CreateClient(auth, queue);

        using var response = await client.GetAsync($"/api/v1/stations/{OtherStationId}/observations");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Empty(queue.Calls);
    }

    [Fact]
    public async Task Review_permission_allows_queue_read_for_authorized_station()
    {
        var queue = new RecordingQueueService
        {
            Next = JsonDocument.Parse("[{\"id\":\"obs-1\"}]").RootElement.Clone()
        };
        var auth = new ConfigurableAuthorizationService();
        auth.Allowed[(UserId, StationId, "observation.review")] = true;

        using var client = CreateClient(auth, queue);
        using var response = await client.GetAsync($"/api/v1/stations/{StationId}/observations?limit=20");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Single(queue.Calls);
        Assert.Equal(StationId, queue.Calls[0].StationId);
        Assert.Equal(20, queue.Calls[0].Limit);
    }

    [Fact]
    public async Task Non_array_queue_payload_is_rejected_as_unavailable()
    {
        var queue = new RecordingQueueService
        {
            Next = JsonDocument.Parse("{\\"unexpected\\":true}").RootElement.Clone()
        };
        var auth = new ConfigurableAuthorizationService();
        auth.Allowed[(UserId, StationId, "observation.review")] = true;

        using var client = CreateClient(auth, queue);
        using var response = await client.GetAsync($"/api/v1/stations/{StationId}/observations");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Single(queue.Calls);
    }

    [Fact]
    public async Task Invalid_limit_is_rejected_before_queue_service()
    {
        var queue = new RecordingQueueService();
        var auth = new ConfigurableAuthorizationService();
        auth.Allowed[(UserId, StationId, "observation.approve")] = true;

        using var client = CreateClient(auth, queue);
        using var response = await client.GetAsync($"/api/v1/stations/{StationId}/observations?limit=0");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Empty(queue.Calls);
    }

    private HttpClient CreateClient(bool allowReview, RecordingQueueService queue)
    {
        var auth = new ConfigurableAuthorizationService();
        if (allowReview)
            auth.Allowed[(UserId, StationId, "observation.review")] = true;
        return CreateClient(auth, queue);
    }

    private HttpClient CreateClient(
        ConfigurableAuthorizationService auth,
        RecordingQueueService queue)
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

                services.RemoveAll<IStationAuthorizationService>();
                services.AddSingleton<IStationAuthorizationService>(auth);

                services.RemoveAll<IObservationQueueService>();
                services.AddSingleton<IObservationQueueService>(queue);
            });
        });

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", "test-token");
        return client;
    }

    private sealed class ConfigurableAuthorizationService : IStationAuthorizationService
    {
        public Dictionary<(Guid UserId, Guid StationId, string Permission), bool> Allowed { get; } = new();

        public bool IsConfigured => true;

        public Task<bool> HasStationPermissionAsync(
            Guid userId, Guid stationId, string permissionCode, CancellationToken cancellationToken = default) =>
            Task.FromResult(Allowed.TryGetValue((userId, stationId, permissionCode), out var ok) && ok);

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid userId, Guid stationId, string permissionCode, CancellationToken cancellationToken = default) =>
            HasStationPermissionAsync(userId, stationId, permissionCode, cancellationToken);

        public Task<bool> HasAuthorityPermissionAsync(
            Guid userId, Guid authorityId, string permissionCode, CancellationToken cancellationToken = default) =>
            Task.FromResult(false);
    }

    private sealed class RecordingQueueService : IObservationQueueService
    {
        public List<(Guid StationId, int Limit)> Calls { get; } = new();
        public JsonElement? Next { get; set; } =
            JsonDocument.Parse("[]").RootElement.Clone();

        public bool IsConfigured => true;

        public Task<JsonElement?> GetSubmittedAsync(
            Guid stationId, int limit, CancellationToken cancellationToken)
        {
            Calls.Add((stationId, limit));
            return Task.FromResult(Next);
        }
    }
}
