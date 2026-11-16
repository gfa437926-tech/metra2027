using System.Net;
using Metra.Api.Features.Stations;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Metra.Api.Tests.Features.Stations;

public sealed class SupabaseStationDirectoryServiceTests
{
    [Fact]
    public async Task User_scope_reads_only_active_assignments_and_memberships_then_queries_their_scope()
    {
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var authorityId = Guid.NewGuid();
        var requestedUris = new List<string>();
        var handler = new StubHandler(request =>
        {
            var uri = request.RequestUri!;
            requestedUris.Add(uri.PathAndQuery);
            if (uri.AbsolutePath.EndsWith("/station_assignments", StringComparison.Ordinal))
                return JsonResponse($"[{{\"station_id\":\"{stationId}\"}}]");
            if (uri.AbsolutePath.EndsWith("/authority_memberships", StringComparison.Ordinal))
                return JsonResponse($"[{{\"authority_id\":\"{authorityId}\"}}]");
            if (uri.AbsolutePath.EndsWith("/station_catalogue", StringComparison.Ordinal))
                return JsonResponse("[]");
            return new HttpResponseMessage(HttpStatusCode.NotFound);
        });
        var service = CreateService(handler);

        var assignments = await service.GetAssignedStationIdsAsync(userId, CancellationToken.None);
        var authorities = await service.GetAuthorityIdsAsync(userId, CancellationToken.None);
        var stations = await service.GetStationsByScopeAsync(
            assignments!, authorities!, null, CancellationToken.None);

        Assert.Equal(new[] { stationId }, assignments);
        Assert.Equal(new[] { authorityId }, authorities);
        Assert.Equal(JsonValueKind.Array, stations!.Value.ValueKind);
        Assert.Contains(requestedUris, uri => uri.Contains("/station_assignments?", StringComparison.Ordinal));
        Assert.Contains(requestedUris, uri => uri.Contains("/authority_memberships?", StringComparison.Ordinal));
        Assert.Contains(requestedUris, uri =>
            uri.Contains("/station_catalogue?", StringComparison.Ordinal) &&
            uri.Contains("or=", StringComparison.Ordinal));
    }

    [Fact]
    public async Task Empty_user_scope_returns_empty_catalogue_without_unscoped_catalogue_request()
    {
        var handler = new StubHandler(_ => throw new InvalidOperationException(
            "No database request is expected for an empty scope."));
        var service = CreateService(handler);

        var rows = await service.GetStationsByScopeAsync(
            Array.Empty<Guid>(), Array.Empty<Guid>(), null, CancellationToken.None);

        Assert.NotNull(rows);
        Assert.Equal(JsonValueKind.Array, rows!.Value.ValueKind);
        Assert.Equal(0, rows.Value.GetArrayLength());
    }

    private static SupabaseStationDirectoryService CreateService(HttpMessageHandler handler)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:ServiceRoleKey"] = "server-only-test-key"
            })
            .Build();

        return new SupabaseStationDirectoryService(new StubHttpClientFactory(handler), configuration);
    }

    private static HttpResponseMessage JsonResponse(string json) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")
    };

    private sealed class StubHttpClientFactory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
    }

    private sealed class StubHandler(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
            => Task.FromResult(responseFactory(request));
    }
}
