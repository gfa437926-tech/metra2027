using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;
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

/// <summary>
/// Station isolation for registration queue reads and decisions.
/// </summary>
public sealed class RegistrationReviewStationAuthorizationTests
{
    [Fact]
    public async Task Unauthorized_user_cannot_read_registration_queue_and_service_is_not_called()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new RegistrationAuthorizationFake(userId, Guid.NewGuid());
        var review = new RegistrationReviewFake();

        await using var factory = CreateFactory(authorization, review);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/registration-requests");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, review.QueueCallCount);
    }

    [Fact]
    public async Task Station_a_cannot_read_registration_queue_for_station_b()
    {
        var userId = Guid.NewGuid();
        var stationA = Guid.NewGuid();
        var stationB = Guid.NewGuid();
        var authorization = new RegistrationAuthorizationFake(userId, stationA);
        var review = new RegistrationReviewFake();

        await using var factory = CreateFactory(authorization, review);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationB}/registration-requests");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, review.QueueCallCount);
        Assert.Contains(stationB, authorization.CheckedStationIds);
    }

    [Fact]
    public async Task Unauthorized_user_cannot_decide_registration_request()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var requestId = Guid.NewGuid();
        var authorization = new RegistrationAuthorizationFake(userId, Guid.NewGuid());
        var review = new RegistrationReviewFake();

        await using var factory = CreateFactory(authorization, review);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{stationId}/registration-requests/{requestId}/decision",
            new { decision = "approve", note = "ok" });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, review.DecisionCallCount);
    }

    [Fact]
    public async Task Authorized_reviewer_reads_requested_station_queue_only()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new RegistrationAuthorizationFake(userId, stationId);
        var review = new RegistrationReviewFake();

        await using var factory = CreateFactory(authorization, review);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/registration-requests?limit=20");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(1, review.QueueCallCount);
        Assert.Equal(stationId, review.RequestedStationId);
        Assert.Equal(20, review.RequestedLimit);
    }

    private static WebApplicationFactory<Program> CreateFactory(
        IStationAuthorizationService authorization,
        IRegistrationReviewService review) =>
        new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureTestServices(services =>
                {
                    services.RemoveAll<IStationAuthorizationService>();
                    services.AddSingleton(authorization);
                    services.RemoveAll<IRegistrationReviewService>();
                    services.AddSingleton(review);
                    services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultChallengeScheme = TestAuthenticationHandler.Scheme;
                        options.DefaultForbidScheme = TestAuthenticationHandler.Scheme;
                    }).AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                        TestAuthenticationHandler.Scheme, _ => { });
                });
            });

    private sealed class RegistrationAuthorizationFake(Guid userId, Guid allowedStationId) : IStationAuthorizationService
    {
        public List<Guid> CheckedStationIds { get; } = [];

        public Task<bool> HasStationPermissionAsync(
            Guid actorUserId, Guid stationId, string permissionCode, CancellationToken cancellationToken = default)
        {
            CheckedStationIds.Add(stationId);
            return Task.FromResult(
                actorUserId == userId &&
                stationId == allowedStationId &&
                permissionCode is "registrations.station.approve");
        }
    }

    private sealed class RegistrationReviewFake : IRegistrationReviewService
    {
        public int QueueCallCount { get; private set; }
        public int DecisionCallCount { get; private set; }
        public Guid RequestedStationId { get; private set; }
        public int RequestedLimit { get; private set; }
        public bool IsConfigured => true;

        public Task<JsonElement?> GetPendingForStationAsync(
            Guid stationId, string expectedStatus, int limit, Guid actorUserId, CancellationToken cancellationToken)
        {
            QueueCallCount++;
            RequestedStationId = stationId;
            RequestedLimit = limit;
            return Task.FromResult<JsonElement?>(JsonSerializer.SerializeToElement(Array.Empty<object>()));
        }

        public Task<JsonElement?> GetAuditForStationAsync(
            Guid stationId, int limit, Guid actorUserId, bool systemStage, CancellationToken cancellationToken) =>
            Task.FromResult<JsonElement?>(JsonSerializer.SerializeToElement(Array.Empty<object>()));

        public Task<RegistrationDecisionOutcome> DecideAsync(
            Guid stationId, string expectedStatus, Guid requestId, Guid actorUserId,
            RegistrationDecisionRequest request, CancellationToken cancellationToken)
        {
            DecisionCallCount++;
            return Task.FromResult(new RegistrationDecisionOutcome(true, true, HttpStatusCode.OK, null));
        }
    }

    private sealed class TestAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public const string Scheme = "Test";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!Request.Headers.TryGetValue("X-Test-User", out var values)
                || !Guid.TryParse(values.ToString(), out var userId))
            {
                return Task.FromResult(AuthenticateResult.Fail("Missing test user."));
            }

            var identity = new ClaimsIdentity(
                [new Claim("sub", userId.ToString()), new Claim(ClaimTypes.NameIdentifier, userId.ToString())],
                Scheme);
            return Task.FromResult(
                AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme)));
        }
    }
}
