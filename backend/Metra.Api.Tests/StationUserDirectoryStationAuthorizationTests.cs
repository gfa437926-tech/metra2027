using System.Net;
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
/// Station isolation for station user directory reads (users.station.view).
/// </summary>
public sealed class StationUserDirectoryStationAuthorizationTests
{
    [Fact]
    public async Task Unauthorized_user_cannot_list_station_users_and_directory_is_not_called()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new DirectoryAuthorizationFake(userId, Guid.NewGuid());
        var directory = new StationUserDirectoryFake();

        await using var factory = CreateFactory(authorization, directory);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/users");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, directory.CallCount);
        Assert.Contains(stationId, authorization.CheckedStationIds);
    }

    [Fact]
    public async Task Authorized_user_lists_only_requested_station_directory()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new DirectoryAuthorizationFake(userId, stationId);
        var directory = new StationUserDirectoryFake();

        await using var factory = CreateFactory(authorization, directory);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/users?limit=10");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(1, directory.CallCount);
        Assert.Equal(stationId, directory.RequestedStationId);
        Assert.Equal(10, directory.RequestedLimit);
    }

    [Fact]
    public async Task Station_a_credentials_cannot_list_users_on_station_b()
    {
        var userId = Guid.NewGuid();
        var stationA = Guid.NewGuid();
        var stationB = Guid.NewGuid();
        var authorization = new DirectoryAuthorizationFake(userId, stationA);
        var directory = new StationUserDirectoryFake();

        await using var factory = CreateFactory(authorization, directory);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationB}/users");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, directory.CallCount);
        Assert.Contains(stationB, authorization.CheckedStationIds);
    }

    private static WebApplicationFactory<Program> CreateFactory(
        IStationAuthorizationService authorization,
        IStationUserDirectoryService directory) =>
        new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureTestServices(services =>
                {
                    services.RemoveAll<IStationAuthorizationService>();
                    services.AddSingleton(authorization);
                    services.RemoveAll<IStationUserDirectoryService>();
                    services.AddSingleton(directory);
                    services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = MetraUserDirTestAuthenticationHandler.Scheme;
                        options.DefaultChallengeScheme = MetraUserDirTestAuthenticationHandler.Scheme;
                        options.DefaultForbidScheme = MetraUserDirTestAuthenticationHandler.Scheme;
                    }).AddScheme<AuthenticationSchemeOptions, MetraUserDirTestAuthenticationHandler>(
                        MetraUserDirTestAuthenticationHandler.Scheme, _ => { });
                });
            });

    private sealed class DirectoryAuthorizationFake(Guid userId, Guid allowedStationId) : IStationAuthorizationService
    {
        public List<Guid> CheckedStationIds { get; } = [];

        public bool IsConfigured => true;

        public Task<bool> HasStationPermissionAsync(
            Guid actorUserId, Guid stationId, string permissionCode, CancellationToken cancellationToken = default)
        {
            CheckedStationIds.Add(stationId);
            return Task.FromResult(
                actorUserId == userId &&
                stationId == allowedStationId &&
                permissionCode == "users.station.view");
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid actorUserId, Guid stationId, string permissionCode, CancellationToken cancellationToken = default) =>
            Task.FromResult(false);
    }

    private sealed class StationUserDirectoryFake : IStationUserDirectoryService
    {
        public int CallCount { get; private set; }
        public Guid RequestedStationId { get; private set; }
        public int RequestedLimit { get; private set; }
        public bool IsConfigured => true;

        public Task<JsonElement?> GetUsersAsync(Guid stationId, int limit, CancellationToken cancellationToken)
        {
            CallCount++;
            RequestedStationId = stationId;
            RequestedLimit = limit;
            return Task.FromResult<JsonElement?>(JsonSerializer.SerializeToElement(Array.Empty<object>()));
        }
    }

    private sealed class MetraUserDirTestAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public new const string Scheme = "MetraUserDirTest";

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
