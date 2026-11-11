using System.Net;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;
using Metra.Api.Features.Observations;
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

public sealed class ObservationQueueStationAuthorizationTests
{
    [Fact]
    public async Task User_without_review_permission_cannot_read_station_queue()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new QueueAuthorizationFake(userId, Guid.NewGuid());
        var queue = new ObservationQueueFake();

        await using var factory = CreateFactory(authorization, queue);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/observations");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, queue.CallCount);
        Assert.Equal(3, authorization.CheckedStationIds.Count);
        Assert.All(authorization.CheckedStationIds, checkedStationId => Assert.Equal(stationId, checkedStationId));
    }

    [Fact]
    public async Task Authorized_reviewer_reads_only_the_requested_station_queue()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new QueueAuthorizationFake(userId, stationId);
        var queue = new ObservationQueueFake();

        await using var factory = CreateFactory(authorization, queue);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/observations?limit=25");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(1, queue.CallCount);
        Assert.Equal(stationId, queue.RequestedStationId);
        Assert.Equal(25, queue.RequestedLimit);
    }

    [Fact]
    public async Task Reviewer_with_decision_specific_permission_can_read_station_queue()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new QueueAuthorizationFake(userId, stationId, "observation.approve");
        var queue = new ObservationQueueFake();

        await using var factory = CreateFactory(authorization, queue);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/observations");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(2, authorization.CheckedStationIds.Count);
        Assert.Equal(1, queue.CallCount);
        Assert.Equal(stationId, queue.RequestedStationId);
    }

    [Fact]
    public async Task Unconfigured_authorization_fails_closed_without_reading_queue()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new QueueAuthorizationFake(userId, stationId) { IsConfigured = false };
        var queue = new ObservationQueueFake();

        await using var factory = CreateFactory(authorization, queue);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/observations");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Empty(authorization.CheckedStationIds);
        Assert.Equal(0, queue.CallCount);
    }

    [Fact]
    public async Task Unconfigured_queue_fails_closed_without_authorization_or_queue_read()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new QueueAuthorizationFake(userId, stationId);
        var queue = new ObservationQueueFake { IsConfigured = false };

        await using var factory = CreateFactory(authorization, queue);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/observations");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Empty(authorization.CheckedStationIds);
        Assert.Equal(0, queue.CallCount);
    }

    [Fact]
    public async Task Failed_queue_read_returns_unavailable_instead_of_an_empty_success()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new QueueAuthorizationFake(userId, stationId);
        var queue = new ObservationQueueFake { ReturnNull = true };

        await using var factory = CreateFactory(authorization, queue);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/observations");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(1, queue.CallCount);
        Assert.Equal(stationId, queue.RequestedStationId);
    }

    [Fact]
    public async Task Invalid_queue_limit_is_rejected_before_authorization_or_read()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new QueueAuthorizationFake(userId, stationId);
        var queue = new ObservationQueueFake();

        await using var factory = CreateFactory(authorization, queue);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/observations?limit=101");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Empty(authorization.CheckedStationIds);
        Assert.Equal(0, queue.CallCount);
    }

    private static WebApplicationFactory<Program> CreateFactory(
        QueueAuthorizationFake authorization,
        ObservationQueueFake queue) =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Development");
            builder.ConfigureTestServices(services =>
            {
                services.AddAuthentication(options =>
                {
                    options.DefaultAuthenticateScheme = QueueTestAuthenticationHandler.Scheme;
                    options.DefaultChallengeScheme = QueueTestAuthenticationHandler.Scheme;
                    options.DefaultForbidScheme = QueueTestAuthenticationHandler.Scheme;
                }).AddScheme<AuthenticationSchemeOptions, QueueTestAuthenticationHandler>(
                    QueueTestAuthenticationHandler.Scheme, _ => { });

                services.RemoveAll<IStationAuthorizationService>();
                services.AddSingleton<IStationAuthorizationService>(authorization);
                services.RemoveAll<IObservationQueueService>();
                services.AddSingleton<IObservationQueueService>(queue);
            });
        });

    private sealed class QueueAuthorizationFake(
        Guid userId,
        Guid allowedStationId,
        string allowedPermission = "observation.review")
        : IStationAuthorizationService
    {
        public bool IsConfigured { get; set; } = true;
        public List<Guid> CheckedStationIds { get; } = [];

        public Task<bool> HasStationPermissionAsync(
            Guid requestedUserId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default)
        {
            CheckedStationIds.Add(stationId);
            return Task.FromResult(
                requestedUserId == userId &&
                stationId == allowedStationId &&
                permissionCode == allowedPermission);
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid requestedUserId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(false);
    }

    private sealed class ObservationQueueFake : IObservationQueueService
    {
        public bool IsConfigured { get; set; } = true;
        public int CallCount { get; private set; }
        public Guid RequestedStationId { get; private set; }
        public int RequestedLimit { get; private set; }
        public bool ReturnNull { get; set; }

        public Task<JsonElement?> GetSubmittedAsync(
            Guid stationId, int limit, CancellationToken cancellationToken)
        {
            CallCount++;
            RequestedStationId = stationId;
            RequestedLimit = limit;
            if (ReturnNull)
                return Task.FromResult<JsonElement?>(null);

            using var document = JsonDocument.Parse("[]");
            return Task.FromResult<JsonElement?>(document.RootElement.Clone());
        }
    }

    private sealed class QueueTestAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public new const string Scheme = "MetraQueueTest";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!Guid.TryParse(Request.Headers["X-Test-User"], out var userId))
                return Task.FromResult(AuthenticateResult.Fail("Missing test user identifier."));

            var identity = new ClaimsIdentity(
                [new Claim("sub", userId.ToString())], Scheme);
            return Task.FromResult(AuthenticateResult.Success(
                new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme)));
        }
    }
}
