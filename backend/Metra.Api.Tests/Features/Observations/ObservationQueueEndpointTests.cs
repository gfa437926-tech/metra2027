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

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationQueueEndpointTests
{
    private static readonly Guid StationId = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");

    [Fact]
    public async Task Unauthenticated_request_returns_401_without_calling_queue()
    {
        using var factory = new QueueApiFactory();
        using var client = factory.CreateClient();

        var response = await client.GetAsync($"/api/v1/stations/{StationId}/observations");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal(0, factory.Queue.Calls);
        Assert.Equal(0, factory.Authorization.Calls);
    }

    [Fact]
    public async Task Invalid_limit_returns_400_without_calling_authorization_or_queue()
    {
        using var factory = new QueueApiFactory();
        using var client = AuthenticatedClient(factory);

        var response = await client.GetAsync($"/api/v1/stations/{StationId}/observations?limit=101");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(0, factory.Authorization.Calls);
        Assert.Equal(0, factory.Queue.Calls);
    }

    [Fact]
    public async Task Denied_station_scope_returns_403_and_never_reads_queue()
    {
        using var factory = new QueueApiFactory();
        factory.Authorization.Allowed = false;
        using var client = AuthenticatedClient(factory);

        var response = await client.GetAsync($"/api/v1/stations/{StationId}/observations");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(3, factory.Authorization.Calls);
        Assert.Equal(0, factory.Queue.Calls);
    }

    [Fact]
    public async Task Unconfigured_queue_dependency_returns_503_without_authorization_or_queue_read()
    {
        using var factory = new QueueApiFactory();
        factory.Queue.IsConfigured = false;
        using var client = AuthenticatedClient(factory);

        var response = await client.GetAsync($"/api/v1/stations/{StationId}/observations");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(0, factory.Authorization.Calls);
        Assert.Equal(0, factory.Queue.Calls);
    }

    [Fact]
    public async Task Queue_dependency_failure_returns_503_after_authorization()
    {
        using var factory = new QueueApiFactory();
        factory.Queue.Result = null;
        using var client = AuthenticatedClient(factory);

        var response = await client.GetAsync($"/api/v1/stations/{StationId}/observations");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal(1, factory.Authorization.Calls);
        Assert.Equal(1, factory.Queue.Calls);
    }

    private static HttpClient AuthenticatedClient(QueueApiFactory factory)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-Auth", "valid");
        return client;
    }
}

internal sealed class QueueApiFactory : WebApplicationFactory<Program>
{
    public FakeStationAuthorization Authorization { get; } = new();
    public FakeObservationQueue Queue { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<IStationAuthorizationService>();
            services.RemoveAll<IObservationQueueService>();
            services.AddSingleton<IStationAuthorizationService>(Authorization);
            services.AddSingleton<IObservationQueueService>(Queue);

            services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = TestAuthenticationHandler.Scheme;
                options.DefaultChallengeScheme = TestAuthenticationHandler.Scheme;
                options.DefaultForbidScheme = TestAuthenticationHandler.Scheme;
            }).AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                TestAuthenticationHandler.Scheme, _ => { });
        });
    }
}

internal sealed class TestAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string Scheme = "MetraTest";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue("X-Test-Auth", out var value) || value != "valid")
            return Task.FromResult(AuthenticateResult.NoResult());

        var identity = new ClaimsIdentity(
            [new Claim("sub", "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")],
            Scheme);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, Scheme);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}

internal sealed class FakeStationAuthorization : IStationAuthorizationService
{
    public bool IsConfigured { get; set; } = true;
    public bool Allowed { get; set; } = true;
    public int Calls { get; private set; }

    public Task<bool> HasStationPermissionAsync(
        Guid userId, Guid stationId, string permissionCode,
        CancellationToken cancellationToken = default)
    {
        Calls++;
        return Task.FromResult(Allowed);
    }

    public Task<bool> HasStationOwnerAuthorityPermissionAsync(
        Guid userId, Guid stationId, string permissionCode,
        CancellationToken cancellationToken = default) =>
        Task.FromResult(false);
}

internal sealed class FakeObservationQueue : IObservationQueueService
{
    public bool IsConfigured { get; set; } = true;
    public int Calls { get; private set; }
    public JsonElement? Result { get; set; } =
        JsonDocument.Parse("[]").RootElement.Clone();

    public Task<JsonElement?> GetSubmittedAsync(
        Guid stationId, int limit, CancellationToken cancellationToken)
    {
        Calls++;
        return Task.FromResult(Result);
    }
}
