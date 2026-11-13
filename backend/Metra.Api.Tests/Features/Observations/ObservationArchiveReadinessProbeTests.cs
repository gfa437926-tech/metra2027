using System.Net;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationArchiveReadinessProbeTests
{
    [Fact]
    public async Task Probe_is_ready_only_when_both_atomic_archive_rpcs_exist_and_deny_empty_actor()
    {
        var handler = new SequenceHandler("station_observation_archive_forbidden", HttpStatusCode.Forbidden, HttpStatusCode.Forbidden);
        var service = CreateService(handler);

        var ready = await service.ProbeAsync(CancellationToken.None);

        Assert.True(ready);
        Assert.Equal(2, handler.Requests.Count);
        Assert.EndsWith("/rest/v1/rpc/get_station_observation_archive_atomic", handler.Requests[0]!.AbsolutePath);
        Assert.EndsWith("/rest/v1/rpc/get_station_observation_archive_item_atomic", handler.Requests[1]!.AbsolutePath);
    }

    [Fact]
    public async Task Probe_fails_when_archive_item_rpc_is_missing()
    {
        var handler = new SequenceHandler("station_observation_archive_forbidden", HttpStatusCode.Forbidden, HttpStatusCode.NotFound);
        var service = CreateService(handler);

        var ready = await service.ProbeAsync(CancellationToken.None);

        Assert.False(ready);
        Assert.Equal(2, handler.Requests.Count);
    }

    [Fact]
    public async Task Probe_fails_if_empty_actor_is_not_denied()
    {
        var handler = new SequenceHandler("station_observation_archive_forbidden", HttpStatusCode.OK, HttpStatusCode.Forbidden);
        var service = CreateService(handler);

        var ready = await service.ProbeAsync(CancellationToken.None);

        Assert.False(ready);
        Assert.Single(handler.Requests);
    }

    [Fact]
    public async Task Probe_fails_when_service_role_is_denied_execute_privilege()
    {
        var handler = new SequenceHandler("permission denied for function get_station_observation_archive_atomic",
            HttpStatusCode.Forbidden, HttpStatusCode.Forbidden);
        var service = CreateService(handler);

        var ready = await service.ProbeAsync(CancellationToken.None);

        Assert.False(ready);
        Assert.Single(handler.Requests);
    }

    [Fact]
    public async Task Probe_fails_closed_when_archive_service_is_not_configured()
    {
        var handler = new SequenceHandler("station_observation_archive_forbidden", HttpStatusCode.Forbidden, HttpStatusCode.Forbidden);
        var service = new SupabaseObservationArchiveService(
            new StaticClientFactory(handler),
            new ConfigurationBuilder().Build());

        var ready = await service.ProbeAsync(CancellationToken.None);

        Assert.False(ready);
        Assert.Empty(handler.Requests);
    }

    private static SupabaseObservationArchiveService CreateService(SequenceHandler handler)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://metra-test.supabase.co",
                ["Supabase:ServiceRoleKey"] = "test-only-placeholder"
            })
            .Build();
        return new SupabaseObservationArchiveService(new StaticClientFactory(handler), configuration);
    }

    private sealed class StaticClientFactory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) =>
            new(handler, disposeHandler: false) { Timeout = TimeSpan.FromSeconds(8) };
    }

    private sealed class SequenceHandler(string forbiddenMessage, params HttpStatusCode[] statuses) : HttpMessageHandler
    {
        private int _index;
        public List<Uri?> Requests { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add(request.RequestUri);
            var status = statuses[Math.Min(_index++, statuses.Length - 1)];
            var body = status switch
            {
                HttpStatusCode.OK => "[]",
                HttpStatusCode.Forbidden => JsonSerializer.Serialize(new { code = "42501", message = forbiddenMessage }),
                _ => string.Empty
            };
            return Task.FromResult(new HttpResponseMessage(status)
            {
                Content = new StringContent(body)
            });
        }
    }
}
