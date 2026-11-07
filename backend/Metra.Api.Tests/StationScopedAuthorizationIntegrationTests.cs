using System.Net;
using System.Security.Claims;
using System.Text;
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

        using var allowedResponse = await client.PostAsync(
            $"/api/v1/stations/{allowedStationId}/observations/{Guid.NewGuid()}/decision",
            new StringContent("{\"decision\":\"approve\",\"note\":null}", Encoding.UTF8, "application/json"));
        using var deniedResponse = await client.PostAsync(
            $"/api/v1/stations/{deniedStationId}/observations/{Guid.NewGuid()}/decision",
            new StringContent("{\"decision\":\"approve\",\"note\":null}", Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.OK, allowedResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, deniedResponse.StatusCode);
        Assert.Equal(1, decisions.CallCount);
        Assert.Equal(new[] { allowedStationId }, authorization.CheckedStationIds);
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
        using var response = await client.PostAsync(
            $"/api/v1/stations/{stationId}/observations/{Guid.NewGuid()}/decision",
            new StringContent("{\"decision\":\"approve\",\"note\":null}", Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(0, decisions.CallCount);
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
            return Task.FromResult(
                IsConfigured &&
                requestedUserId == userId &&
                stationId == allowedStationId &&
                permissionCode == "observation.approve");
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid requestedUserId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(false);
    }

    private sealed class ObservationDecisionFake : IObservationDecisionService
    {
        public bool IsConfigured => true;
        public int CallCount { get; private set; }

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
        public const string Scheme = "MetraTest";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var identity = new ClaimsIdentity(
                [new Claim("sub", TestUserId.Value.ToString())], Scheme);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme);
            return Task.FromResult(AuthenticateResult.Success(ticket));
        }

        private static readonly Lazy<Guid> TestUserId = new(Guid.NewGuid());
    }
}
