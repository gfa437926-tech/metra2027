using Metra.Api.Features.Users;
using Metra.Api.Security;
using Microsoft.Extensions.Configuration;
using System.Net;
using System.Text;
using System.Text.Json;
using Xunit;

namespace Metra.Api.Tests.Features.Users;

public sealed class AccessContextServiceTests
{
    [Fact]
    public async Task Missing_configuration_returns_null_and_is_not_configured()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co"
            })
            .Build();

        var service = new SupabaseAccessContextService(
            new StubHttpClientFactory(_ => throw new InvalidOperationException()),
            configuration,
            new FakeAuthorization());

        Assert.False(service.IsConfigured);
        Assert.Null(await service.BuildAsync(Guid.NewGuid(), CancellationToken.None));
    }

    [Fact]
    public async Task Empty_user_fails_closed()
    {
        var service = CreateService(
            _ => new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("[]", Encoding.UTF8, "application/json")
            },
            new FakeAuthorization());

        Assert.Null(await service.BuildAsync(Guid.Empty, CancellationToken.None));
    }

    [Fact]
    public async Task User_with_no_assignments_returns_empty_stations()
    {
        var service = CreateService(
            _ => new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("[]", Encoding.UTF8, "application/json")
            },
            new FakeAuthorization());

        var userId = Guid.NewGuid();
        var context = await service.BuildAsync(userId, CancellationToken.None);

        Assert.NotNull(context);
        Assert.Equal(userId, context!.UserId);
        Assert.Equal("unknown", context.AccountState);
        Assert.Empty(context.Stations);
        Assert.Empty(context.Authorities);
    }

    [Fact]
    public async Task Single_station_permissions_come_from_rpc_not_role_name()
    {
        var stationId = Guid.Parse("11111111-1111-1111-1111-111111111111");
        var authorization = new FakeAuthorization(stationPermission: code =>
            code is "observation.create" or "observation.submit");

        var service = CreateService(request =>
        {
            var path = request.RequestUri!.AbsolutePath;
            if (path.Contains("station_assignments"))
            {
                var body = JsonSerializer.Serialize(new[]
                {
                    new { station_id = stationId, role_code = "observer" }
                });
                return JsonOk(body);
            }

            if (path.Contains("authority_memberships"))
                return JsonOk("[]");

            return JsonOk("[]");
        }, authorization);

        var context = await service.BuildAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.NotNull(context);
        Assert.Single(context!.Stations);
        Assert.Equal(stationId, context.Stations[0].StationId);
        Assert.Equal("observer", context.Stations[0].RoleCode);
        Assert.Equal(
            new[] { "observation.create", "observation.submit" },
            context.Stations[0].Permissions);
        // Role name alone must not grant review.
        Assert.DoesNotContain("observation.review", context.Stations[0].Permissions);
    }

    [Fact]
    public async Task Multiple_stations_can_carry_different_permissions()
    {
        var stationA = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
        var stationB = Guid.Parse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
        var authorization = new FakeAuthorization(stationPermission: (stationId, code) =>
        {
            if (stationId == stationA)
                return code is "observation.create" or "observation.submit";
            if (stationId == stationB)
                return code is "observation.review" or "users.station.view";
            return false;
        });

        var service = CreateService(request =>
        {
            if (request.RequestUri!.AbsolutePath.Contains("station_assignments"))
            {
                var body = JsonSerializer.Serialize(new object[]
                {
                    new { station_id = stationA, role_code = "observer" },
                    new { station_id = stationB, role_code = "station_head" }
                });
                return JsonOk(body);
            }

            return JsonOk("[]");
        }, authorization);

        var context = await service.BuildAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.NotNull(context);
        Assert.Equal(2, context!.Stations.Count);
        var a = context.Stations.Single(s => s.StationId == stationA);
        var b = context.Stations.Single(s => s.StationId == stationB);
        Assert.Contains("observation.create", a.Permissions);
        Assert.DoesNotContain("observation.review", a.Permissions);
        Assert.Contains("observation.review", b.Permissions);
        Assert.DoesNotContain("observation.create", b.Permissions);
    }

    [Fact]
    public async Task Assignment_without_any_granted_permission_is_omitted()
    {
        var stationId = Guid.NewGuid();
        var service = CreateService(request =>
        {
            if (request.RequestUri!.AbsolutePath.Contains("station_assignments"))
            {
                var body = JsonSerializer.Serialize(new[]
                {
                    new { station_id = stationId, role_code = "observer" }
                });
                return JsonOk(body);
            }

            return JsonOk("[]");
        }, new FakeAuthorization(stationPermission: _ => false));

        var context = await service.BuildAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.NotNull(context);
        Assert.Empty(context!.Stations);
    }

    [Fact]
    public async Task Postgrest_failure_fails_closed()
    {
        var service = CreateService(
            _ => new HttpResponseMessage(HttpStatusCode.ServiceUnavailable),
            new FakeAuthorization(stationPermission: _ => true));

        Assert.Null(await service.BuildAsync(Guid.NewGuid(), CancellationToken.None));
    }

    private static SupabaseAccessContextService CreateService(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory,
        IStationAuthorizationService authorization)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:ServiceRoleKey"] = "server-only-test-key"
            })
            .Build();

        return new SupabaseAccessContextService(
            new StubHttpClientFactory(responseFactory),
            configuration,
            authorization);
    }

    private static HttpResponseMessage JsonOk(string json) =>
        new(HttpStatusCode.OK)
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };

    private sealed class FakeAuthorization : IStationAuthorizationService
    {
        private readonly Func<Guid, string, bool> _stationPermission;
        private readonly Func<string, bool> _authorityPermission;

        public FakeAuthorization(
            Func<string, bool>? stationPermission = null,
            Func<Guid, string, bool>? stationPermissionWithId = null,
            Func<string, bool>? authorityPermission = null,
            bool isConfigured = true)
        {
            IsConfigured = isConfigured;
            _stationPermission = stationPermissionWithId ??
                ((_, code) => stationPermission?.Invoke(code) ?? false);
            _authorityPermission = authorityPermission ?? (_ => false);
        }

        // Convenience overload used by tests via optional named args above.
        public FakeAuthorization(
            Func<Guid, string, bool> stationPermission,
            Func<string, bool>? authorityPermission = null)
            : this(stationPermissionWithId: stationPermission, authorityPermission: authorityPermission)
        {
        }

        public bool IsConfigured { get; }

        public Task<bool> HasStationPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(_stationPermission(stationId, permissionCode));

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(false);

        public Task<bool> HasAuthorityPermissionAsync(
            Guid userId, Guid authorityId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(_authorityPermission(permissionCode));
    }

    private sealed class StubHttpClientFactory(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) =>
            new(new StubHandler(responseFactory), disposeHandler: false);
    }

    private sealed class StubHandler(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken) =>
            Task.FromResult(responseFactory(request));
    }
}
