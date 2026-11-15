using System.Net;
using System.Net.Http.Headers;
using System.Text;
using Microsoft.Extensions.Configuration;
using Metra.Api.Features.Stations;
using Xunit;

namespace Metra.Api.Tests.Features.Stations;

public sealed class SupabaseGreenfieldStationDirectoryReaderTests
{
    private const string StationRow = """
    [{
      "id":"11111111-1111-1111-1111-111111111111",
      "station_code":"NEW-001",
      "name_ar":"محطة تجريبية",
      "name_en":"Sample station",
      "wmo_identifier":"40001",
      "approval_status":"approved",
      "operational_status":"active",
      "elevation_m":512.4,
      "timezone_name":"Asia/Damascus",
      "station_types":{"type_code":"synoptic","name_ar":"رصدية","name_en":"Synoptic"},
      "station_locations":[{
        "latitude":35.5,
        "longitude":36.2,
        "location_source":"official_record",
        "horizontal_accuracy_m":4.5,
        "valid_to":null
      }]
    }]
    """;

    [Fact]
    public async Task Reads_catalog_projection_with_callers_validated_jwt_and_publishable_key()
    {
        HttpRequestMessage? captured = null;
        var reader = CreateReader(new StubHandler(request =>
        {
            captured = request;
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(StationRow, Encoding.UTF8, "application/json")
            };
        }));

        var result = await reader.GetStationsAsync("caller-user-jwt", 25, 0, "synoptic", default);

        Assert.NotNull(captured);
        Assert.Equal("Bearer", captured.Headers.Authorization?.Scheme);
        Assert.Equal("caller-user-jwt", captured.Headers.Authorization?.Parameter);
        Assert.Contains(captured.Headers.GetValues("apikey"), value => value == "sb_publishable_test");
        Assert.Contains(captured.Headers.GetValues("Accept-Profile"), value => value == "catalog");
        Assert.Contains("/rest/v1/stations?", captured.RequestUri!.PathAndQuery);
        Assert.Contains("station_types.type_code", captured.RequestUri.PathAndQuery);
        Assert.NotNull(result);
        Assert.True(result!.Succeeded);
        var station = Assert.Single(result.Stations);
        Assert.Equal("NEW-001", station.StationCode);
        Assert.Equal("synoptic", station.StationTypeCode);
        Assert.Equal(35.5m, station.Latitude);
        Assert.Equal(36.2m, station.Longitude);
    }

    [Fact]
    public async Task Rejects_multiple_current_locations_instead_of_multiplying_station()
    {
        var twoLocations = StationRow.Replace(
            "\"valid_to\":null\n      }]\n    }]",
            "\"valid_to\":null\n      },{\n        \"latitude\":35.6,\n        \"longitude\":36.3,\n        \"location_source\":\"survey\",\n        \"horizontal_accuracy_m\":5,\n        \"valid_to\":null\n      }]\n    }]");
        var reader = CreateReader(new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(twoLocations, Encoding.UTF8, "application/json")
        }));

        var result = await reader.GetStationsAsync("caller-user-jwt", 25, 0, null, default);

        Assert.NotNull(result);
        Assert.False(result!.Succeeded);
        Assert.Empty(result.Stations);
    }

    [Fact]
    public async Task Does_not_call_supabase_when_publishable_key_is_missing()
    {
        var calls = 0;
        var reader = CreateReader(new StubHandler(_ =>
        {
            calls++;
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(StationRow, Encoding.UTF8, "application/json")
            };
        }), includeKey: false);

        Assert.False(reader.IsConfigured);
        Assert.Null(await reader.GetStationsAsync("caller-user-jwt", 25, 0, null, default));
        Assert.Equal(0, calls);
    }

    private static SupabaseGreenfieldStationDirectoryReader CreateReader(
        HttpMessageHandler handler, bool includeKey = true)
    {
        var values = new Dictionary<string, string?>
        {
            ["Supabase:Url"] = "https://example.supabase.co"
        };
        if (includeKey)
            values["Supabase:PublishableKey"] = "sb_publishable_test";

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
