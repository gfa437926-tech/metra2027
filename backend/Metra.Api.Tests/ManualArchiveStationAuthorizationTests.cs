using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using Metra.Api.Domain.Archive;
using Metra.Api.Features.Archive;
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
/// Phase G: station isolation for manual Excel archive confirmation ledger.
/// </summary>
public sealed class ManualArchiveStationAuthorizationTests
{
    [Fact]
    public async Task Unauthorized_user_cannot_list_archive_confirmations_and_ledger_is_not_called()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new ArchiveAuthorizationFake(userId, Guid.NewGuid());
        var ledger = new ArchiveLedgerFake();

        await using var factory = CreateFactory(authorization, ledger);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/archive-confirmations");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, ledger.ListCallCount);
    }

    [Fact]
    public async Task Unauthorized_user_cannot_confirm_archive_and_ledger_is_not_called()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new ArchiveAuthorizationFake(userId, Guid.NewGuid());
        var ledger = new ArchiveLedgerFake();

        await using var factory = CreateFactory(authorization, ledger);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{stationId}/archive-confirmations",
            new
            {
                reportKind = "daily",
                periodStartUtc = "2026-11-01",
                periodEndUtc = "2026-11-30",
                excelFileName = "nov.xlsx",
                note = "archived"
            });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, ledger.ConfirmCallCount);
    }

    [Fact]
    public async Task User_of_station_A_cannot_read_archive_ledger_of_station_B()
    {
        var userId = Guid.NewGuid();
        var stationA = Guid.NewGuid();
        var stationB = Guid.NewGuid();
        var authorization = new ArchiveAuthorizationFake(userId, stationA);
        var ledger = new ArchiveLedgerFake();

        await using var factory = CreateFactory(authorization, ledger);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationB}/archive-confirmations");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, ledger.ListCallCount);
        Assert.All(authorization.CheckedStationIds, id => Assert.Equal(stationB, id));
    }

    [Fact]
    public async Task Authorized_reader_lists_only_requested_station()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new ArchiveAuthorizationFake(userId, stationId, "archive.read");
        var ledger = new ArchiveLedgerFake();

        await using var factory = CreateFactory(authorization, ledger);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/archive-confirmations?limit=20");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(1, ledger.ListCallCount);
        Assert.Equal(stationId, ledger.LastListStationId);
        Assert.Equal(20, ledger.LastListLimit);
    }

    [Fact]
    public async Task Authorized_confirmer_can_write_only_for_allowed_station()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorization = new ArchiveAuthorizationFake(
            userId, stationId, "archive.read", "archive.confirm");
        var ledger = new ArchiveLedgerFake();

        await using var factory = CreateFactory(authorization, ledger);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{stationId}/archive-confirmations",
            new
            {
                reportKind = "hourly",
                periodStartUtc = "2026-11-10",
                periodEndUtc = "2026-11-10",
                excelFileName = "h.xlsx",
                note = (string?)null
            });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.Equal(1, ledger.ConfirmCallCount);
        Assert.Equal(stationId, ledger.LastConfirmStationId);
        Assert.Equal(userId, ledger.LastConfirmActorId);
    }

    [Fact]
    public async Task Cross_station_confirm_is_forbidden_even_with_home_station_grants()
    {
        var userId = Guid.NewGuid();
        var stationA = Guid.NewGuid();
        var stationB = Guid.NewGuid();
        var authorization = new ArchiveAuthorizationFake(
            userId, stationA, "archive.read", "archive.confirm");
        var ledger = new ArchiveLedgerFake();

        await using var factory = CreateFactory(authorization, ledger);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.PostAsJsonAsync(
            $"/api/v1/stations/{stationB}/archive-confirmations",
            new
            {
                reportKind = "daily",
                periodStartUtc = "2026-11-01",
                periodEndUtc = "2026-11-01",
                excelFileName = "x.xlsx"
            });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, ledger.ConfirmCallCount);
    }

    [Fact]
    public async Task Monthly_summary_requires_archive_read_on_target_station()
    {
        var userId = Guid.NewGuid();
        var stationA = Guid.NewGuid();
        var stationB = Guid.NewGuid();
        var authorization = new ArchiveAuthorizationFake(userId, stationA, "archive.read");
        var ledger = new ArchiveLedgerFake();

        await using var factory = CreateFactory(authorization, ledger);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-User", userId.ToString());

        using var response = await client.GetAsync(
            $"/api/v1/stations/{stationB}/archive-confirmations/monthly-summary?year=2026&month=11");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Equal(0, ledger.SummaryCallCount);
    }

    [Fact]
    public async Task Unauthenticated_archive_list_is_rejected()
    {
        var stationId = Guid.NewGuid();
        var authorization = new ArchiveAuthorizationFake(Guid.NewGuid(), stationId);
        var ledger = new ArchiveLedgerFake();

        await using var factory = CreateFactory(authorization, ledger);
        using var client = factory.CreateClient();

        using var response = await client.GetAsync($"/api/v1/stations/{stationId}/archive-confirmations");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal(0, ledger.ListCallCount);
    }

    private static WebApplicationFactory<Program> CreateFactory(
        ArchiveAuthorizationFake authorization,
        ArchiveLedgerFake ledger) =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Development");
            builder.ConfigureTestServices(services =>
            {
                services.AddAuthentication(options =>
                {
                    options.DefaultAuthenticateScheme = ArchiveTestAuthenticationHandler.Scheme;
                    options.DefaultChallengeScheme = ArchiveTestAuthenticationHandler.Scheme;
                    options.DefaultForbidScheme = ArchiveTestAuthenticationHandler.Scheme;
                }).AddScheme<AuthenticationSchemeOptions, ArchiveTestAuthenticationHandler>(
                    ArchiveTestAuthenticationHandler.Scheme, _ => { });

                services.RemoveAll<IStationAuthorizationService>();
                services.AddSingleton<IStationAuthorizationService>(authorization);
                services.RemoveAll<IManualArchiveLedgerService>();
                services.AddSingleton<IManualArchiveLedgerService>(ledger);
            });
        });

    private sealed class ArchiveAuthorizationFake(
        Guid userId,
        Guid allowedStationId,
        params string[] allowedPermissions) : IStationAuthorizationService
    {
        private readonly HashSet<string> _allowed =
            allowedPermissions.Length == 0
                ? new HashSet<string>(StringComparer.Ordinal)
                : new HashSet<string>(allowedPermissions, StringComparer.Ordinal);

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
                (_allowed.Count == 0 ? false : _allowed.Contains(permissionCode)));
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid requestedUserId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(false);
    }

    private sealed class ArchiveLedgerFake : IManualArchiveLedgerService
    {
        public bool IsConfigured => true;
        public int ListCallCount { get; private set; }
        public int ConfirmCallCount { get; private set; }
        public int SummaryCallCount { get; private set; }
        public Guid LastListStationId { get; private set; }
        public int LastListLimit { get; private set; }
        public Guid LastConfirmStationId { get; private set; }
        public Guid LastConfirmActorId { get; private set; }

        public Task<ManualArchiveServiceOutcome> ListAsync(Guid stationId, int limit, CancellationToken ct)
        {
            ListCallCount++;
            LastListStationId = stationId;
            LastListLimit = limit;
            return Task.FromResult(new ManualArchiveServiceOutcome(
                true, HttpStatusCode.OK, Array.Empty<ManualArchiveConfirmation>()));
        }

        public Task<ManualArchiveServiceOutcome> ConfirmAsync(
            Guid stationId, Guid actorUserId, ManualArchiveConfirmRequest request, CancellationToken ct)
        {
            ConfirmCallCount++;
            LastConfirmStationId = stationId;
            LastConfirmActorId = actorUserId;
            var entry = new ManualArchiveConfirmation(
                Guid.NewGuid(), stationId, actorUserId, "hourly",
                DateOnly.Parse("2026-11-10"), DateOnly.Parse("2026-11-10"),
                "h.xlsx", null, DateTimeOffset.UtcNow);
            return Task.FromResult(new ManualArchiveServiceOutcome(
                true, HttpStatusCode.Created, entry));
        }

        public Task<ManualArchiveServiceOutcome> MonthlySummaryAsync(
            Guid stationId, int year, int month, CancellationToken ct)
        {
            SummaryCallCount++;
            return Task.FromResult(new ManualArchiveServiceOutcome(
                true, HttpStatusCode.OK, new ManualArchiveMonthlySummary(year, month, 0, [])));
        }
    }

    private sealed class ArchiveTestAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public new const string Scheme = "MetraArchiveTest";

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
