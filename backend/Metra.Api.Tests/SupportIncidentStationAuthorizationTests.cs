using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;
using Metra.Api.Features.Support;
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

public sealed class SupportIncidentStationAuthorizationTests
{
    [Fact]
    public async Task Unauthorized_user_cannot_list_support_incidents_and_service_is_not_called()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new SupportAuthorizationFake(userId, allowedStationId: Guid.NewGuid());
        var incidents = new SupportIncidentServiceFake();

        await using var factory = CreateFactory(authorization, incidents);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/support-incidents");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, incidents.ListCallCount);
    }

    [Fact]
    public async Task Unauthorized_user_cannot_submit_support_incident_and_service_is_not_called()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new SupportAuthorizationFake(userId, allowedStationId: Guid.NewGuid());
        var incidents = new SupportIncidentServiceFake();

        await using var factory = CreateFactory(authorization, incidents);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{stationId}/support-incidents",
            new
            {
                kind = "InformationTechnology",
                category = "شبكة",
                title = "انقطاع خدمة الشبكة الداخلية",
                description = "تعذر الاتصال بخادم النقل منذ 30 دقيقة",
                severity = "High",
                occurredAt = DateTimeOffset.UtcNow,
                impactsOperations = true
            });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, incidents.SubmitCallCount);
    }

    [Fact]
    public async Task Authorized_user_lists_only_requested_station_incidents()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new SupportAuthorizationFake(userId, stationId);
        var incidents = new SupportIncidentServiceFake();

        await using var factory = CreateFactory(authorization, incidents);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/support-incidents?limit=15");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(1, incidents.ListCallCount);
        Assert.Equal(stationId, incidents.LastListStationId);
        Assert.Equal(15, incidents.LastListLimit);
    }

    private static WebApplicationFactory<Program> CreateFactory(
        IStationAuthorizationService authorization,
        ISupportIncidentService incidents) =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Development");
            builder.ConfigureTestServices(services =>
            {
                services.AddAuthentication(options =>
                {
                    options.DefaultAuthenticateScheme = SupportTestAuthenticationHandler.Scheme;
                    options.DefaultChallengeScheme = SupportTestAuthenticationHandler.Scheme;
                    options.DefaultForbidScheme = SupportTestAuthenticationHandler.Scheme;
                }).AddScheme<AuthenticationSchemeOptions, SupportTestAuthenticationHandler>(
                    SupportTestAuthenticationHandler.Scheme, _ => { });

                services.RemoveAll<IStationAuthorizationService>();
                services.AddSingleton(authorization);
                services.RemoveAll<ISupportIncidentService>();
                services.AddSingleton(incidents);
            });
        });

    private sealed class SupportAuthorizationFake(Guid userId, Guid allowedStationId) : IStationAuthorizationService
    {
        public bool IsConfigured => true;

        public Task<bool> HasStationPermissionAsync(
            Guid authenticatedUserId,
            Guid stationId,
            string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(
                authenticatedUserId == userId
                && stationId == allowedStationId
                && permissionCode.StartsWith("support_incident.", StringComparison.Ordinal));

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid authenticatedUserId,
            Guid stationId,
            string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(false);
    }

    private sealed class SupportIncidentServiceFake : ISupportIncidentService
    {
        public bool IsConfigured => true;
        public int ListCallCount { get; private set; }
        public int SubmitCallCount { get; private set; }
        public Guid? LastListStationId { get; private set; }
        public int? LastListLimit { get; private set; }

        public Task<SupportIncidentServiceOutcome> SubmitAsync(
            Guid userId,
            Guid stationId,
            SupportIncidentSubmitRequest request,
            CancellationToken cancellationToken)
        {
            SubmitCallCount++;
            return Task.FromResult(new SupportIncidentServiceOutcome(
                true, true, HttpStatusCode.Created, JsonDocument.Parse("{}").RootElement));
        }

        public Task<SupportIncidentServiceOutcome> ListAsync(
            Guid stationId,
            int limit,
            CancellationToken cancellationToken)
        {
            ListCallCount++;
            LastListStationId = stationId;
            LastListLimit = limit;
            return Task.FromResult(new SupportIncidentServiceOutcome(
                true, true, HttpStatusCode.OK, JsonDocument.Parse("[]").RootElement));
        }

        public Task<SupportIncidentServiceOutcome> TransitionAsync(
            Guid userId,
            Guid stationId,
            Guid incidentId,
            SupportIncidentTransitionRequest request,
            CancellationToken cancellationToken) =>
            Task.FromResult(new SupportIncidentServiceOutcome(
                true, true, HttpStatusCode.OK, JsonDocument.Parse("{}").RootElement));
    }

    private sealed class SupportTestAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public new const string Scheme = "MetraSupportIncidentTest";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!Request.Headers.TryGetValue("X-Test-User", out var values)
                || !Guid.TryParse(values.FirstOrDefault(), out var userId))
            {
                return Task.FromResult(AuthenticateResult.Fail("missing user"));
            }

            var identity = new ClaimsIdentity(
            [
                new Claim("sub", userId.ToString()),
                new Claim(ClaimTypes.NameIdentifier, userId.ToString())
            ], Scheme);
            return Task.FromResult(AuthenticateResult.Success(
                new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme)));
        }
    }
}
