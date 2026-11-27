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
        var authorization = new FakeAuthorization(
            stationPermission: (id, code) =>
                id == stationId && code is "observation.create" or "observation.submit");

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
    public async Task Authority_membership_permissions_are_scoped_to_the_authority_id()
    {
        var authorityId = Guid.Parse("cccccccc-cccc-cccc-cccc-cccccccccccc");
        var authorization = new FakeAuthorization(
            authorityPermission: (id, code) =>
                id == authorityId && code is
                    "stations.catalogue.review" or
                    "authority.access.review" or
                    "authority.access.revoke");

        var service = CreateService(request =>
        {
            if (request.RequestUri!.AbsolutePath.Contains("authority_memberships"))
            {
                var body = JsonSerializer.Serialize(new[]
                {
                    new { authority_id = authorityId, role_code = "system_reviewer" }
                });
                return JsonOk(body);
            }

            return JsonOk("[]");
        }, authorization);

        var context = await service.BuildAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.NotNull(context);
        var authority = Assert.Single(context!.Authorities);
        Assert.Equal(authorityId, authority.AuthorityId);
        Assert.Equal("system_reviewer", authority.RoleCode);
        Assert.Equal(
            new[]
            {
                "stations.catalogue.review",
                "authority.access.review",
                "authority.access.revoke"
            },
            authority.Permissions);
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
        }, new FakeAuthorization());

        var context = await service.BuildAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.NotNull(context);
        Assert.Empty(context!.Stations);
    }

    [Fact]
    public async Task Authority_membership_read_failure_fails_closed_even_when_station_read_succeeds()
    {
        var requests = new List<string>();
        var service = CreateService(request =>
        {
            var path = request.RequestUri!.AbsolutePath;
            requests.Add(path);
            if (path.Contains("station_assignments"))
                return JsonOk("[]");
            if (path.Contains("authority_memberships"))
                return new HttpResponseMessage(HttpStatusCode.ServiceUnavailable);
            throw new InvalidOperationException($"Unexpected request: {path}");
        }, new FakeAuthorization());

        var context = await service.BuildAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.Null(context);
        Assert.Contains(requests, path => path.Contains("station_assignments"));
        Assert.Contains(requests, path => path.Contains("authority_memberships"));
    }


    [Fact]
    public async Task Assignment_read_over_the_safety_limit_fails_closed_without_permission_probes()
    {
        var permissionProbes = 0;
        var authorization = new FakeAuthorization(
            stationPermission: (_, _) =>
            {
                permissionProbes++;
                return true;
            });
        var service = CreateService(request =>
        {
            if (request.RequestUri!.AbsolutePath.Contains("station_assignments"))
            {
                var rows = Enumerable.Range(1, 101)
                    .Select(_ => new { station_id = Guid.NewGuid(), role_code = "observer" });
                return JsonOk(JsonSerializer.Serialize(rows));
            }

            return JsonOk("[]");
        }, authorization);

        var context = await service.BuildAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.Null(context);
        Assert.Equal(0, permissionProbes);
    }

    [Fact]
    public async Task Authority_membership_read_over_the_safety_limit_fails_closed()
    {
        var permissionProbes = 0;
        var authorization = new FakeAuthorization(
            authorityPermission: (_, _) =>
            {
                permissionProbes++;
                return true;
            });
        var service = CreateService(request =>
        {
            if (request.RequestUri!.AbsolutePath.Contains("authority_memberships"))
            {
                var rows = Enumerable.Range(1, 101)
                    .Select(_ => new { authority_id = Guid.NewGuid(), role_code = "reviewer" });
                return JsonOk(JsonSerializer.Serialize(rows));
            }

            return JsonOk("[]");
        }, authorization);

        var context = await service.BuildAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.Null(context);
        Assert.Equal(0, permissionProbes);
    }

    [Theory]
    [InlineData("station_assignments", "station_id")]
    [InlineData("authority_memberships", "authority_id")]
    public async Task Malformed_membership_row_fails_closed_without_permission_probes(
        string table,
        string idColumn)
    {
        var permissionProbes = 0;
        var authorization = new FakeAuthorization(
            stationPermission: (_, _) =>
            {
                permissionProbes++;
                return true;
            },
            authorityPermission: (_, _) =>
            {
                permissionProbes++;
                return true;
            });
        var service = CreateService(request =>
        {
            if (request.RequestUri!.AbsolutePath.Contains(table))
                return JsonOk($"[{{\"{idColumn}\":123,\"role_code\":\"observer\"}}]");
            return JsonOk("[]");
        }, authorization);

        var context = await service.BuildAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.Null(context);
        Assert.Equal(0, permissionProbes);
    }

    [Theory]
    [InlineData("station_assignments", "station_id")]
    [InlineData("authority_memberships", "authority_id")]
    public async Task Malformed_role_code_fails_closed_without_permission_probes(
        string table,
        string idColumn)
    {
        var permissionProbes = 0;
        var authorization = new FakeAuthorization(
            stationPermission: (_, _) => { permissionProbes++; return true; },
            authorityPermission: (_, _) => { permissionProbes++; return true; });
        var service = CreateService(request =>
        {
            if (request.RequestUri!.AbsolutePath.Contains(table))
            {
                var row = new Dictionary<string, object?>
                {
                    [idColumn] = Guid.NewGuid(),
                    ["role_code"] = 123
                };
                return JsonOk(JsonSerializer.Serialize(new[] { row }));
                return JsonOk(body);
            }

            return JsonOk("[]");
        }, authorization);

        var context = await service.BuildAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.Null(context);
        Assert.Equal(0, permissionProbes);
    }

    [Theory]
    [InlineData("station_assignments", "station_id")]
    [InlineData("authority_memberships", "authority_id")]
    public async Task Duplicate_membership_scope_fails_closed_without_permission_probes(
        string table,
        string idColumn)
    {
        var duplicateId = Guid.Parse("eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee");
        var permissionProbes = 0;
        var authorization = new FakeAuthorization(
            stationPermission: (_, _) => { permissionProbes++; return true; },
            authorityPermission: (_, _) => { permissionProbes++; return true; });
        var service = CreateService(request =>
        {
            if (request.RequestUri!.AbsolutePath.Contains(table))
            {
                var row = "{\"" + idColumn + "\":\"" + duplicateId + "\",\"role_code\":\"observer\"}";
                var body = $"[{row},{row}]";
                return JsonOk(body);
            }

            return JsonOk("[]");
        }, authorization);

        var context = await service.BuildAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.Null(context);
        Assert.Equal(0, permissionProbes);
    }

    [Fact]
    public async Task Postgrest_failure_fails_closed()
    {
        var service = CreateService(
            _ => new HttpResponseMessage(HttpStatusCode.ServiceUnavailable),
            new FakeAuthorization(stationPermission: (_, _) => true));

        Assert.Null(await service.BuildAsync(Guid.NewGuid(), CancellationToken.None));
    }

    [Fact]
    public async Task Assignment_and_membership_reads_are_user_scoped_approved_time_valid_and_bounded()
    {
        var userId = Guid.Parse("dddddddd-dddd-dddd-dddd-dddddddddddd");
        var queries = new List<string>();
        var service = CreateService(request =>
        {
            queries.Add(Uri.UnescapeDataString(request.RequestUri!.Query));
            return JsonOk("[]");
        }, new FakeAuthorization());

        var context = await service.BuildAsync(userId, CancellationToken.None);

        Assert.NotNull(context);
        Assert.Equal(2, queries.Count);
        foreach (var query in queries)
        {
            Assert.Contains($"user_id=eq.{userId}", query);
            Assert.Contains("approval_status=eq.approved", query);
            Assert.Contains("valid_from=lte.", query);
            Assert.Contains("valid_to.is.null", query);
            Assert.Contains("valid_to.gt.", query);
            Assert.Contains("limit=101", query);
        }

        Assert.Contains("select=station_id,role_code", queries[0]);
        Assert.Contains("select=authority_id,role_code", queries[1]);
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

    private sealed class FakeAuthorization(
        Func<Guid, string, bool>? stationPermission = null,
        Func<Guid, string, bool>? authorityPermission = null,
        bool isConfigured = true) : IStationAuthorizationService
    {
        public bool IsConfigured { get; } = isConfigured;

        public Task<bool> HasStationPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(stationPermission?.Invoke(stationId, permissionCode) ?? false);

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(false);

        public Task<bool> HasAuthorityPermissionAsync(
            Guid userId, Guid authorityId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(authorityPermission?.Invoke(authorityId, permissionCode) ?? false);
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
