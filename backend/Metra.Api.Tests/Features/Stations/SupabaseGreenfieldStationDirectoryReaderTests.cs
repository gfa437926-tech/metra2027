using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Metra.Api.Features.Stations;
using Xunit;

namespace Metra.Api.Tests.Features.Stations;

public sealed class SupabaseGreenfieldStationDirectoryReaderTests
{
    private static readonly Guid ActorId =
        Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");

    private const string StationRows = """
    [{
      "id":"11111111-1111-1111-1111-111111111111",
      "station_code":"NEW-001",
      "name_ar":"محطة تجريبية",
      "name_en":"Sample station",
      "wmo_identifier":"40001",
      "station_type_code":"synoptic",
      "station_type_name_ar":"رصدية",
      "station_type_name_en":"Synoptic",
      "approval_status":"approved",
      "operational_status":"active",
      "latitude":35.5,
      "longitude":36.2,
      "elevation_m":512.4,
      "timezone_name":"Asia/Damascus",
      "location_source":"official_record",
      "horizontal_accuracy_m":4.5
    }]
    """;

    [Fact]
    public async Task Calls_only_atomic_actor_bound_rpc_with_server_key_and_validated_actor_id()
    {
        HttpRequestMessage? captured = null;
        var reader = CreateReader(new StubHandler(request =>
        {
            captured = request;
            return Ok(StationRows);
        }));

        var result = await reader.GetStationsAsync(ActorId, 25, 5, "synoptic", default);

        Assert.NotNull(captured);
        Assert.Equal(HttpMethod.Post, captured.Method);
        Assert.EndsWith("/rest/v1/rpc/get_station_directory_for_actor", captured.RequestUri!.AbsoluteUri);
        Assert.Equal("Bearer", captured.Headers.Authorization?.Scheme);
        Assert.Equal("sb_secret_server_test", captured.Headers.Authorization?.Parameter);
        Assert.Contains(captured.Headers.GetValues("apikey"), value => value == "sb_secret_server_test");
        Assert.False(captured.Headers.Contains("Content-Profile"));

        using var body = JsonDocument.Parse(await captured.Content!.ReadAsStringAsync());
        Assert.Equal(ActorId, body.RootElement.GetProperty("p_actor_user_id").GetGuid());
        Assert.Equal(25, body.RootElement.GetProperty("p_limit").GetInt32());
        Assert.Equal(5, body.RootElement.GetProperty("p_offset").GetInt32());
        Assert.Equal("synoptic", body.RootElement.GetProperty("p_station_type_code").GetString());

        Assert.NotNull(result);
        Assert.True(result!.Succeeded);
        var station = Assert.Single(result.Stations);
        Assert.Equal("NEW-001", station.StationCode);
        Assert.Equal("synoptic", station.StationTypeCode);
        Assert.Equal(35.5m, station.Latitude);
        Assert.Equal(36.2m, station.Longitude);
    }

    [Fact]
    public async Task Does_not_call_supabase_until_feature_is_explicitly_enabled()
    {
        var calls = 0;
        var reader = CreateReader(new StubHandler(_ =>
        {
            calls++;
            return Ok(StationRows);
        }), enabled: false);

        Assert.False(reader.IsConfigured);
        Assert.Null(await reader.GetStationsAsync(ActorId, 25, 0, null, default));
        Assert.Equal(0, calls);
    }

    [Fact]
    public async Task Does_not_call_supabase_when_server_key_is_missing()
    {
        var calls = 0;
        var reader = CreateReader(new StubHandler(_ =>
        {
            calls++;
            return Ok(StationRows);
        }), includeKey: false);

        Assert.False(reader.IsConfigured);
        Assert.Null(await reader.GetStationsAsync(ActorId, 25, 0, null, default));
        Assert.Equal(0, calls);
    }

    [Fact]
    public async Task Rejects_publishable_key_in_server_key_configuration()
    {
        var calls = 0;
        var reader = CreateReader(new StubHandler(_ =>
        {
            calls++;
            return Ok(StationRows);
        }), serviceKey: "sb_publishable_not_a_server_secret");

        Assert.False(reader.IsConfigured);
        Assert.Null(await reader.GetStationsAsync(ActorId, 25, 0, null, default));
        Assert.Equal(0, calls);
    }

    [Fact]
    public async Task Rejects_empty_actor_before_network_call()
    {
        var calls = 0;
        var reader = CreateReader(new StubHandler(_ =>
        {
            calls++;
            return Ok(StationRows);
        }));

        Assert.Null(await reader.GetStationsAsync(Guid.Empty, 25, 0, null, default));
        Assert.Equal(0, calls);
    }

    [Fact]
    public async Task Fails_closed_when_atomic_rpc_is_unavailable()
    {
        var reader = CreateReader(new StubHandler(_ =>
            new HttpResponseMessage(HttpStatusCode.Forbidden)));

        Assert.Null(await reader.GetStationsAsync(ActorId, 25, 0, null, default));
    }

    [Fact]
    public async Task Rejects_non_array_rpc_projection()
    {
        var reader = CreateReader(new StubHandler(_ => Ok("""{"items":[]}""")));

        Assert.Null(await reader.GetStationsAsync(ActorId, 25, 0, null, default));
    }

    private static HttpResponseMessage Ok(string json) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(json, Encoding.UTF8, "application/json")
    };

    private static SupabaseGreenfieldStationDirectoryReader CreateReader(
        HttpMessageHandler handler,
        bool includeKey = true,
        bool enabled = true,
        string serviceKey = "sb_secret_server_test")
    {
        var values = new Dictionary<string, string?>
        {
            ["Supabase:Url"] = "https://example.supabase.co",
            ["Features:GreenfieldStationDirectoryEnabled"] = enabled.ToString().ToLowerInvariant()
        };
        if (includeKey)
            values["Supabase:ServiceRoleKey"] = serviceKey;

        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(values)
            .Build();
        return new SupabaseGreenfieldStationDirectoryReader(
            new StubClientFactory(new HttpClient(handler)), configuration);
    }

    private sealed class StubClientFactory(HttpClient client) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => client;
    }

    private sealed class StubHandler(Func<HttpRequestMessage, HttpResponseMessage> send)
        : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(send(request));
    }
}
