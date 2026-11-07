using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;
using Metra.Api.Features.Maintenance;
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

public sealed class EquipmentFaultStationAuthorizationTests
{
    [Fact]
    public async Task Unauthorized_user_cannot_list_equipment_faults_and_service_is_not_called()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new FaultAuthorizationFake(userId, allowedStationId: Guid.NewGuid());
        var faults = new EquipmentFaultServiceFake();

        await using var factory = CreateFactory(authorization, faults);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/equipment-faults");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, faults.ListCallCount);
    }

    [Fact]
    public async Task Unauthorized_user_cannot_submit_equipment_fault_and_service_is_not_called()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new FaultAuthorizationFake(userId, allowedStationId: Guid.NewGuid());
        var faults = new EquipmentFaultServiceFake();

        await using var factory = CreateFactory(authorization, faults);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{stationId}/equipment-faults",
            new
            {
                equipmentCategory = "أجهزة الرصد",
                equipmentName = "مقياس حرارة",
                description = "توقف الجهاز عن الإرسال منذ ساعتين",
                severity = "High",
                occurredAt = DateTimeOffset.UtcNow,
                isOperationallyBlocking = true
            });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, faults.SubmitCallCount);
    }

    [Fact]
    public async Task Authorized_user_lists_only_requested_station_faults()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new FaultAuthorizationFake(userId, stationId);
        var faults = new EquipmentFaultServiceFake();

        await using var factory = CreateFactory(authorization, faults);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/equipment-faults?limit=20");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(1, faults.ListCallCount);
        Assert.Equal(stationId, faults.LastListStationId);
        Assert.Equal(20, faults.LastListLimit);
    }

    private static WebApplicationFactory<Program> CreateFactory(
        IStationAuthorizationService authorization,
        IEquipmentFaultService faults) =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
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
                services.AddSingleton(authorization);
                services.RemoveAll<IEquipmentFaultService>();
                services.AddSingleton(faults);
            });
        });

    private sealed class FaultAuthorizationFake(Guid userId, Guid allowedStationId) : IStationAuthorizationService
    {
        public bool IsConfigured => true;

        public Task<bool> HasStationPermissionAsync(
            Guid authenticatedUserId,
            Guid stationId,
            string permissionCode,
            CancellationToken cancellationToken = default)
        {
            return Task.FromResult(
                authenticatedUserId == userId
                && stationId == allowedStationId
                && permissionCode.StartsWith("equipment_fault.", StringComparison.Ordinal));
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid authenticatedUserId,
            Guid stationId,
            string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(false);
    }

    private sealed class EquipmentFaultServiceFake : IEquipmentFaultService
    {
        public bool IsConfigured => true;
        public int ListCallCount { get; private set; }
        public int SubmitCallCount { get; private set; }
        public Guid? LastListStationId { get; private set; }
        public int? LastListLimit { get; private set; }

        public Task<EquipmentFaultServiceOutcome> SubmitAsync(
            Guid userId,
            Guid stationId,
            EquipmentFaultSubmitRequest request,
            CancellationToken cancellationToken)
        {
            SubmitCallCount++;
            return Task.FromResult(new EquipmentFaultServiceOutcome(
                true, true, HttpStatusCode.Created, JsonDocument.Parse("{}").RootElement));
        }

        public Task<EquipmentFaultServiceOutcome> ListAsync(
            Guid stationId,
            int limit,
            CancellationToken cancellationToken)
        {
            ListCallCount++;
            LastListStationId = stationId;
            LastListLimit = limit;
            return Task.FromResult(new EquipmentFaultServiceOutcome(
                true, true, HttpStatusCode.OK, JsonDocument.Parse("[]").RootElement));
        }

        public Task<EquipmentFaultServiceOutcome> TransitionAsync(
            Guid userId,
            Guid stationId,
            Guid faultId,
            EquipmentFaultTransitionRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(new EquipmentFaultServiceOutcome(
                true, true, HttpStatusCode.OK, JsonDocument.Parse("{}").RootElement));
        }
    }

    private sealed class TestAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public new const string Scheme = "MetraEquipmentFaultTest";

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
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme);
            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }
}
