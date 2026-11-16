using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
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
/// HTTP-level tests for POST /api/v1/stations/{stationId}/observations.
/// Proves RequestGuard + DomainValidator run before the submission service.
/// Does not call Supabase RPC (service is replaced with an in-memory stub).
/// </summary>
public sealed class HourlyDailySubmissionEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private static readonly Guid StationId = Guid.Parse("11111111-1111-4111-8111-111111111111");
    private static readonly Guid OtherStationId = Guid.Parse("22222222-2222-4222-8222-222222222222");
    private static readonly Guid UserId = Guid.Parse(TestAuthHandler.DefaultUserId);

    private readonly WebApplicationFactory<Program> _factory;

    public HourlyDailySubmissionEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Unauthenticated_submit_is_rejected()
    {
        using var client = _factory.CreateClient();
        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{StationId}/observations",
            ValidHourlyBody("key-unauth"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Authenticated_user_without_station_permission_is_forbidden()
    {
        var submission = new RecordingSubmissionService();
        using var client = CreateClient(
            allowPermission: false,
            submission: submission);

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{StationId}/observations",
            ValidHourlyBody("key-forbidden"));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Empty(submission.Calls);
    }

    [Fact]
    public async Task Domain_validation_rejects_invalid_hourly_before_persistence()
    {
        var submission = new RecordingSubmissionService();
        using var client = CreateClient(allowPermission: true, submission: submission);

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{StationId}/observations",
            new
            {
                idempotencyKey = "key-invalid-hourly",
                observationType = "hourly",
                observedAt = "2026-11-16T00:00:00Z",
                payload = new { utcTime = "00", dryTemp = 8.0, wetTemp = 10.0 },
                submit = true
            });

        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
        Assert.Empty(submission.Calls);
    }

    [Fact]
    public async Task Domain_validation_rejects_invalid_daily_before_persistence()
    {
        var submission = new RecordingSubmissionService();
        using var client = CreateClient(allowPermission: true, submission: submission);

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{StationId}/observations",
            new
            {
                idempotencyKey = "key-invalid-daily",
                observationType = "daily",
                observedAt = "2026-11-16T00:00:00Z",
                payload = new
                {
                    currentDate = "2026-11-16",
                    minTemp = 21.0,
                    maxTemp = 20.0,
                    precipitation = 0.0,
                    snowThickness = 0,
                    evaporation = 1.0,
                    sunshineDuration = 1.0,
                    sunshinePercentage = 10,
                    maxGustSpeed = 5,
                    maxGustDirection = 18,
                    maxGustTime = 12.0,
                    maxHumidity = 90,
                    maxHumidityTime = 6.0,
                    minHumidity = 20,
                    minHumidityTime = 14.0,
                    responsibilityAgreement = true
                },
                submit = true
            });

        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
        Assert.Empty(submission.Calls);
    }

    [Fact]
    public async Task Valid_hourly_reaches_submission_service_with_same_station_and_user()
    {
        var submission = new RecordingSubmissionService();
        using var client = CreateClient(allowPermission: true, submission: submission);

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{StationId}/observations",
            ValidHourlyBody("key-hourly-ok"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Single(submission.Calls);
        var call = submission.Calls[0];
        Assert.Equal(UserId, call.UserId);
        Assert.Equal(StationId, call.StationId);
        Assert.Equal("key-hourly-ok", call.Request.IdempotencyKey);
        Assert.Equal("hourly", call.Request.ObservationType);
        Assert.True(call.Request.ObservedAt?.Offset == TimeSpan.Zero ||
                    call.Request.ObservedAt?.ToUniversalTime().Offset == TimeSpan.Zero);
    }

    [Fact]
    public async Task Valid_daily_reaches_submission_service()
    {
        var submission = new RecordingSubmissionService();
        using var client = CreateClient(allowPermission: true, submission: submission);

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{StationId}/observations",
            ValidDailyBody("key-daily-ok"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Single(submission.Calls);
        Assert.Equal("daily", submission.Calls[0].Request.ObservationType);
    }

    [Fact]
    public async Task Repeated_identical_idempotency_key_is_forwarded_to_service_each_time()
    {
        // API layer does not dedupe; idempotency is the RPC's responsibility.
        // This test documents that the same key is passed through unchanged.
        var submission = new RecordingSubmissionService();
        using var client = CreateClient(allowPermission: true, submission: submission);

        var body = ValidHourlyBody("stable-idem-key");
        using var first = await client.PostAsJsonAsync(
            $"/api/v1/stations/{StationId}/observations", body);
        using var second = await client.PostAsJsonAsync(
            $"/api/v1/stations/{StationId}/observations", body);

        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        Assert.Equal(2, submission.Calls.Count);
        Assert.All(submission.Calls, c => Assert.Equal("stable-idem-key", c.Request.IdempotencyKey));
    }

    [Fact]
    public async Task Service_conflict_maps_to_http_409()
    {
        var submission = new RecordingSubmissionService
        {
            NextOutcome = new ObservationSubmissionOutcome(
                true, false, HttpStatusCode.Conflict, null)
        };
        using var client = CreateClient(allowPermission: true, submission: submission);

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{StationId}/observations",
            ValidHourlyBody("key-conflict"));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task Permission_check_uses_route_station_id_not_client_body_station()
    {
        // Body cannot override route station; authorization is evaluated on route stationId.
        var auth = new ConfigurableAuthorizationService();
        auth.Allowed[(UserId, OtherStationId, "observation.create")] = true;
        // StationId (route) is NOT allowed.
        var submission = new RecordingSubmissionService();
        using var client = CreateClient(auth, submission);

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{StationId}/observations",
            ValidHourlyBody("key-station-scope"));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Empty(submission.Calls);
    }

    [Fact]
    public async Task Guard_rejects_unsupported_type_before_domain_and_service()
    {
        var submission = new RecordingSubmissionService();
        using var client = CreateClient(allowPermission: true, submission: submission);

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{StationId}/observations",
            new
            {
                idempotencyKey = "key-agri",
                observationType = "agricultural",
                observedAt = "2026-11-16T00:00:00Z",
                payload = new { temperature = 20 },
                submit = true
            });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Empty(submission.Calls);
    }

    private HttpClient CreateClient(bool allowPermission, RecordingSubmissionService submission)
    {
        var auth = new ConfigurableAuthorizationService();
        if (allowPermission)
            auth.Allowed[(UserId, StationId, "observation.create")] = true;
        return CreateClient(auth, submission);
    }

    private HttpClient CreateClient(
        ConfigurableAuthorizationService auth,
        RecordingSubmissionService submission)
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

                services.RemoveAll<IObservationSubmissionService>();
                services.AddSingleton<IObservationSubmissionService>(submission);
            });
        });

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", "test-token");
        return client;
    }

    private static object ValidHourlyBody(string key) => new
    {
        idempotencyKey = key,
        observationType = "hourly",
        observedAt = "2026-11-16T00:00:00Z",
        payload = new
        {
            utcTime = "00",
            dryTemp = 15.2,
            wetTemp = 10.1,
            stationPressure = 1000.0,
            seaLevelPressure = 1010.0,
            relativeHumidity = 50,
            dewPoint = 5.1,
            windDirection = 18,
            windSpeed = 3,
            visibility = 10,
            totalCloudCover = 4,
            cover12 = 4,
            cover123 = 4,
            precipitationAmount = 0.0,
            pressureSlope = 0.0,
            pressureShape = 0,
            pastWeather = 0,
            responsibilityAgreement = true
        },
        submit = true
    };

    private static object ValidDailyBody(string key) => new
    {
        idempotencyKey = key,
        observationType = "daily",
        observedAt = "2026-11-16T12:00:00Z",
        payload = new
        {
            currentDate = "2026-11-16",
            minTemp = 5.2,
            maxTemp = 20.3,
            precipitation = 2.1,
            snowThickness = 0,
            evaporation = 1.2,
            sunshineDuration = 8.0,
            sunshinePercentage = 50,
            maxGustSpeed = 10,
            maxGustDirection = 18,
            maxGustTime = 14.0,
            maxHumidity = 90,
            maxHumidityTime = 6.0,
            minHumidity = 20,
            minHumidityTime = 14.0,
            responsibilityAgreement = true
        },
        submit = true
    };

    private sealed class ConfigurableAuthorizationService : IStationAuthorizationService
    {
        public Dictionary<(Guid UserId, Guid StationId, string Permission), bool> Allowed { get; } = new();

        public bool IsConfigured => true;

        public Task<bool> HasStationPermissionAsync(
            Guid userId, Guid stationId, string permissionCode, CancellationToken cancellationToken) =>
            Task.FromResult(Allowed.TryGetValue((userId, stationId, permissionCode), out var ok) && ok);

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid userId, Guid stationId, string permissionCode, CancellationToken cancellationToken) =>
            HasStationPermissionAsync(userId, stationId, permissionCode, cancellationToken);
    }

    private sealed class RecordingSubmissionService : IObservationSubmissionService
    {
        public List<(Guid UserId, Guid StationId, ObservationSubmissionRequest Request)> Calls { get; } = new();

        public ObservationSubmissionOutcome NextOutcome { get; set; } =
            new(true, true, HttpStatusCode.OK, JsonDocument.Parse("{\"ok\":true}").RootElement.Clone());

        public bool IsConfigured => true;

        public Task<ObservationSubmissionOutcome> SubmitAsync(
            Guid userId,
            Guid stationId,
            ObservationSubmissionRequest request,
            CancellationToken cancellationToken)
        {
            Calls.Add((userId, stationId, request));
            return Task.FromResult(NextOutcome);
        }
    }
}
