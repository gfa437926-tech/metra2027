using System.Net;
using System.Security.Claims;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using Metra.Api.Features.Observations;
using Metra.Api.Features.Users;
using Metra.Api.Security;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Xunit;

namespace Metra.Api.Tests;

public sealed class StationScopedAuthorizationIntegrationTests
{
    [Fact]
    public async Task User_can_decide_observations_only_for_the_authorized_station()
    {
        var userId = Guid.NewGuid();
        var allowedStationId = Guid.NewGuid();
        var deniedStationId = Guid.NewGuid();
        var authorization = new StationScopedAuthorizationFake(userId, allowedStationId);
        var decisions = new ObservationDecisionFake();

        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureTestServices(services =>
                {
                    services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultChallengeScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultForbidScheme = TestAuthenticationHandler.Scheme;
                    }).AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                        TestAuthenticationHandler.Scheme, _ => { });

                    services.RemoveAll<IStationAuthorizationService>();
                    services.AddSingleton<IStationAuthorizationService>(authorization);
                    services.RemoveAll<IObservationDecisionService>();
                    services.AddSingleton<IObservationDecisionService>(decisions);
                });
            });

        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var allowedResponse = await client.PostAsync(
            $"/api/v1/stations/{allowedStationId}/observations/{Guid.NewGuid()}/decision",
            new StringContent("{\"decision\":\"approve\",\"note\":null}", Encoding.UTF8, "application/json"));
        using var deniedResponse = await client.PostAsync(
            $"/api/v1/stations/{deniedStationId}/observations/{Guid.NewGuid()}/decision",
            new StringContent("{\"decision\":\"approve\",\"note\":null}", Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.OK, allowedResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, deniedResponse.StatusCode);
        Assert.Equal(1, decisions.CallCount);
        Assert.Equal(new[] { allowedStationId, deniedStationId }, authorization.CheckedStationIds);
    }

    [Fact]
    public async Task Observation_submission_is_blocked_before_persistence_for_an_unassigned_station()
    {
        var userId = Guid.NewGuid();
        var requestedStationId = Guid.NewGuid();
        var authorization = new StationScopedAuthorizationFake(userId, Guid.NewGuid());
        var submission = new ObservationSubmissionFake();

        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureTestServices(services =>
                {
                    services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultChallengeScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultForbidScheme = TestAuthenticationHandler.Scheme;
                    }).AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                        TestAuthenticationHandler.Scheme, _ => { });
                    services.RemoveAll<IStationAuthorizationService>();
                    services.AddSingleton<IStationAuthorizationService>(authorization);
                    services.RemoveAll<IObservationSubmissionService>();
                    services.AddSingleton<IObservationSubmissionService>(submission);
                });
            });

        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());
        using var response = await client.PostAsync(
            $"/api/v1/stations/{requestedStationId}/observations",
            new StringContent(
                "{\"idempotencyKey\":\"station-scope-test\",\"observationType\":\"hourly\",\"observedAt\":\"2026-11-07T00:00:00Z\",\"payload\":{},\"submit\":false}",
                Encoding.UTF8,
                "application/json"));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, submission.CallCount);
        Assert.Contains(requestedStationId, authorization.CheckedStationIds);
    }

    [Fact]
    public async Task Authorization_service_failure_does_not_grant_station_access()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new StationScopedAuthorizationFake(userId, stationId)
        {
            IsConfigured = false
        };
        var decisions = new ObservationDecisionFake();

        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureTestServices(services =>
                {
                    services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultChallengeScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultForbidScheme = TestAuthenticationHandler.Scheme;
                    }).AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                        TestAuthenticationHandler.Scheme, _ => { });
                    services.RemoveAll<IStationAuthorizationService>();
                    services.AddSingleton<IStationAuthorizationService>(authorization);
                    services.RemoveAll<IObservationDecisionService>();
                    services.AddSingleton<IObservationDecisionService>(decisions);
                });
            });

        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());
        using var response = await client.PostAsync(
            $"/api/v1/stations/{stationId}/observations/{Guid.NewGuid()}/decision",
            new StringContent("{\"decision\":\"approve\",\"note\":null}", Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(0, decisions.CallCount);
    }

    [Fact]
    public async Task User_cannot_approve_their_own_observation()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var observationId = Guid.NewGuid();
        var authorization = new StationScopedAuthorizationFake(userId, stationId);
        var decisions = new ObservationDecisionFake
        {
            OwnershipCreatedBy = userId
        };

        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureTestServices(services =>
                {
                    services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultChallengeScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultForbidScheme = TestAuthenticationHandler.Scheme;
                    }).AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                        TestAuthenticationHandler.Scheme, _ => { });
                    services.RemoveAll<IStationAuthorizationService>();
                    services.AddSingleton<IStationAuthorizationService>(authorization);
                    services.RemoveAll<IObservationDecisionService>();
                    services.AddSingleton<IObservationDecisionService>(decisions);
                });
            });

        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());
        using var response = await client.PostAsync(
            $"/api/v1/stations/{stationId}/observations/{observationId}/decision",
            new StringContent(
                "{\"decision\":\"approve\",\"note\":null}",
                Encoding.UTF8,
                "application/json"));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal(0, decisions.CallCount);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("self_review_forbidden", body);
    }

    [Fact]
    public async Task Direct_hourly_submission_rejects_missing_conditional_fields_before_persistence()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new StationScopedAuthorizationFake(userId, stationId);
        var submission = new ObservationSubmissionFake();

        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureTestServices(services =>
                {
                    services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultChallengeScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultForbidScheme = TestAuthenticationHandler.Scheme;
                    }).AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                        TestAuthenticationHandler.Scheme, _ => { });
                    services.RemoveAll<IStationAuthorizationService>();
                    services.AddSingleton<IStationAuthorizationService>(authorization);
                    services.RemoveAll<IObservationSubmissionService>();
                    services.AddSingleton<IObservationSubmissionService>(submission);
                });
            });

        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());
        const string request = """
        {
          "idempotencyKey":"hourly-invalid-00",
          "observationType":"hourly",
          "observedAt":"2026-11-09T00:00:00Z",
          "submit":true,
          "payload":{"values":{
            "utcTime":"00","dryTemp":"+25.0","wetTemp":"+18.0",
            "dewPoint":"+12.0","stationPressure":"1013.2",
            "seaLevelPressure":"1015.0","relativeHumidity":"045",
            "windDirection":"18","windSpeed":"05","visibility":"010",
            "totalCloudCover":"4","cover12":"3","cover123":"4"
          }}
        }
        """;

        using var response = await client.PostAsync(
            $"/api/v1/stations/{stationId}/observations",
            new StringContent(request, Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(0, submission.CallCount);
        Assert.Contains("invalid_observation_fields", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Direct_daily_submission_rejects_missing_24_hour_fields_before_persistence()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new StationScopedAuthorizationFake(userId, stationId);
        var submission = new ObservationSubmissionFake();

        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureTestServices(services =>
                {
                    services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultChallengeScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultForbidScheme = TestAuthenticationHandler.Scheme;
                    }).AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                        TestAuthenticationHandler.Scheme, _ => { });
                    services.RemoveAll<IStationAuthorizationService>();
                    services.AddSingleton<IStationAuthorizationService>(authorization);
                    services.RemoveAll<IObservationSubmissionService>();
                    services.AddSingleton<IObservationSubmissionService>(submission);
                });
            });

        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());
        const string request = """
        {
          "idempotencyKey":"daily-invalid-24h",
          "observationType":"daily",
          "observedAt":"2026-11-08T00:00:00Z",
          "submit":true,
          "payload":{
            "reportType":"24h",
            "responsibilityAgreement":true,
            "values":{"minTemp":"-05.3","maxTemp":"25.7","precipitation":"012.5","snowThickness":"015"}
          }
        }
        """;

        using var response = await client.PostAsync(
            $"/api/v1/stations/{stationId}/observations",
            new StringContent(request, Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(0, submission.CallCount);
        Assert.Contains("invalid_observation_fields", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Direct_valid_hourly_submission_reaches_persistence_after_contract_validation()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new StationScopedAuthorizationFake(userId, stationId);
        var submission = new ObservationSubmissionFake();

        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureTestServices(services =>
                {
                    services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultChallengeScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultForbidScheme = TestAuthenticationHandler.Scheme;
                    }).AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                        TestAuthenticationHandler.Scheme, _ => { });
                    services.RemoveAll<IStationAuthorizationService>();
                    services.AddSingleton<IStationAuthorizationService>(authorization);
                    services.RemoveAll<IObservationSubmissionService>();
                    services.AddSingleton<IObservationSubmissionService>(submission);
                });
            });

        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());
        const string request = """
        {
          "idempotencyKey":"hourly-valid-12",
          "observationType":"hourly",
          "observedAt":"2026-11-09T12:00:00Z",
          "submit":true,
          "payload":{"values":{
            "utcTime":"12","dryTemp":"+25.0","wetTemp":"+18.0",
            "dewPoint":"+12.0","stationPressure":"1013.2",
            "seaLevelPressure":"1015.0","relativeHumidity":"045",
            "windDirection":"18","windSpeed":"05","visibility":"010",
            "totalCloudCover":"4","cover12":"3","cover123":"4",
            "precipitationAmount":"000.0","pressureSlope":"1.2",
            "pressureShape":"3","pastWeather":"0"
          }}
        }
        """;

        using var response = await client.PostAsync(
            $"/api/v1/stations/{stationId}/observations",
            new StringContent(request, Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(1, submission.CallCount);
    }

    private sealed class StationScopedAuthorizationFake(Guid userId, Guid allowedStationId)
        : IStationAuthorizationService
    {
        public bool IsConfigured { get; set; } = true;
        public List<Guid> CheckedStationIds { get; } = [];

        public Task<bool> HasStationPermissionAsync(
            Guid requestedUserId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default)
        {
            CheckedStationIds.Add(stationId);
            var allowedPermissions = new HashSet<string>(StringComparer.Ordinal)
            {
                "observation.approve",
                "observation.create",
                "observation.review",
                "observation.return_for_correction",
                "users.station.view",
                "users.station.manage"
            };
            return Task.FromResult(
                IsConfigured &&
                requestedUserId == userId &&
                stationId == allowedStationId &&
                allowedPermissions.Contains(permissionCode));
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid requestedUserId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(false);
    }

    private sealed class ObservationSubmissionFake : IObservationSubmissionService
    {
        public bool IsConfigured => true;
        public int CallCount { get; private set; }

        public Task<ObservationSubmissionOutcome> SubmitAsync(
            Guid userId, Guid stationId, ObservationSubmissionRequest request,
            CancellationToken cancellationToken)
        {
            CallCount++;
            using var document = JsonDocument.Parse("{\"accepted\":true}");
            return Task.FromResult(new ObservationSubmissionOutcome(
                true, true, HttpStatusCode.OK, document.RootElement.Clone()));
        }
    }

    private sealed class ObservationDecisionFake : IObservationDecisionService
    {
        public bool IsConfigured => true;
        public int CallCount { get; private set; }
        public Guid? OwnershipCreatedBy { get; set; }

        public Task<ObservationOwnership?> GetOwnershipAsync(
            Guid stationId, Guid observationId, CancellationToken cancellationToken)
        {
            var owner = OwnershipCreatedBy ?? Guid.Parse("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
            return Task.FromResult<ObservationOwnership?>(
                new ObservationOwnership(observationId, stationId, owner, "submitted"));
        }

        public Task<ObservationDecisionOutcome> DecideAsync(
            Guid userId, Guid stationId, Guid observationId,
            ObservationDecisionRequest request, CancellationToken cancellationToken)
        {
            CallCount++;
            using var document = JsonDocument.Parse("{\"accepted\":true}");
            return Task.FromResult(new ObservationDecisionOutcome(
                true, true, HttpStatusCode.OK, document.RootElement.Clone()));
        }
    }


    private sealed class TestAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public new const string Scheme = "MetraTest";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!Guid.TryParse(Request.Headers["X-Test-User"], out var userId))
                return Task.FromResult(AuthenticateResult.Fail("Missing test user identifier."));

            var identity = new ClaimsIdentity(
                [new Claim("sub", userId.ToString())], Scheme);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme);
            return Task.FromResult(AuthenticateResult.Success(ticket));
        }

    }
    [Fact]
    public async Task User_can_read_audit_log_only_for_the_authorized_station()
    {
        var userId = Guid.NewGuid();
        var allowedStationId = Guid.NewGuid();
        var deniedStationId = Guid.NewGuid();
        var authorization = new StationScopedAuthorizationFake(userId, allowedStationId);
        var audit = new StationAuditFake();

        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureTestServices(services =>
                {
                    services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultChallengeScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultForbidScheme = TestAuthenticationHandler.Scheme;
                    }).AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                        TestAuthenticationHandler.Scheme, _ => { });

                    services.RemoveAll<IStationAuthorizationService>();
                    services.AddSingleton<IStationAuthorizationService>(authorization);
                    services.RemoveAll<IStationAuditService>();
                    services.AddSingleton<IStationAuditService>(audit);
                });
            });

        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var allowedResponse = await client.GetAsync(
            $"/api/v1/stations/{allowedStationId}/audit-log");
        using var deniedResponse = await client.GetAsync(
            $"/api/v1/stations/{deniedStationId}/audit-log");

        Assert.Equal(HttpStatusCode.OK, allowedResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, deniedResponse.StatusCode);
        Assert.Equal(1, audit.CallCount);
        Assert.Equal(new[] { allowedStationId, deniedStationId }, authorization.CheckedStationIds);
    }

    [Fact]
    public async Task Station_assignment_request_is_denied_before_rpc_for_another_station()
    {
        var userId = Guid.NewGuid();
        var allowedStationId = Guid.NewGuid();
        var deniedStationId = Guid.NewGuid();
        var authorization = new StationScopedAuthorizationFake(userId, allowedStationId);
        var assignments = new StationAssignmentFake();

        await using var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureTestServices(services =>
                {
                    services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultChallengeScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultForbidScheme = TestAuthenticationHandler.Scheme;
                    }).AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                        TestAuthenticationHandler.Scheme, _ => { });
                    services.RemoveAll<IStationAuthorizationService>();
                    services.AddSingleton<IStationAuthorizationService>(authorization);
                    services.RemoveAll<IStationAssignmentService>();
                    services.AddSingleton<IStationAssignmentService>(assignments);
                });
            });

        using var client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());
        using var response = await client.PostAsync(
            $"/api/v1/stations/{deniedStationId}/assignments",
            new StringContent(
                "{\"userId\":\"22222222-2222-4222-8222-222222222222\",\"roleCode\":\"observer\",\"reason\":\"approved station staffing need\",\"validFrom\":\"2026-11-09T08:00:00Z\",\"validTo\":null}",
                Encoding.UTF8,
                "application/json"));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, assignments.RequestCallCount);
        Assert.Contains(deniedStationId, authorization.CheckedStationIds);
    }

    private sealed class StationAssignmentFake : IStationAssignmentService
    {
        public bool IsConfigured => true;
        public int RequestCallCount { get; private set; }

        public Task<JsonElement?> GetAssignableRolesAsync(CancellationToken cancellationToken) =>
            Task.FromResult<JsonElement?>(null);

        public Task<StationAssignmentOutcome> RequestAsync(
            Guid stationId, Guid actorUserId, StationAssignmentRequest request,
            CancellationToken cancellationToken)
        {
            RequestCallCount++;
            using var document = JsonDocument.Parse("{\"status\":\"created\"}");
            return Task.FromResult(new StationAssignmentOutcome(
                true, true, HttpStatusCode.OK, document.RootElement.Clone()));
        }

        public Task<StationAssignmentOutcome> DecideAsync(
            Guid stationId, Guid assignmentId, Guid actorUserId,
            StationAssignmentDecisionRequest request, CancellationToken cancellationToken) =>
            Task.FromResult(new StationAssignmentOutcome(false, false, null, null));

        public Task<StationAssignmentOutcome> RevokeAsync(
            Guid stationId, Guid assignmentId, Guid actorUserId,
            StationAssignmentRevocationRequest request, CancellationToken cancellationToken) =>
            Task.FromResult(new StationAssignmentOutcome(false, false, null, null));
    }

    private sealed class StationAuditFake : IStationAuditService
    {
        public bool IsConfigured => true;
        public int CallCount { get; private set; }

        public Task<JsonElement?> GetAuditAsync(Guid stationId, int limit, CancellationToken cancellationToken)
        {
            CallCount++;
            using var document = JsonDocument.Parse("[]");
            return Task.FromResult<JsonElement?>(document.RootElement.Clone());
        }
    }

}
