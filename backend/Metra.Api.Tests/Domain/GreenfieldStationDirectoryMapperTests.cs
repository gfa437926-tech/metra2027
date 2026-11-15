using System.Text.Json;
using Metra.Api.Domain.Stations;
using Xunit;

namespace Metra.Api.Tests.Domain;

public sealed class GreenfieldStationDirectoryMapperTests
{
    private static JsonElement Payload(string json)
    {
        using var document = JsonDocument.Parse(json);
        return document.RootElement.Clone();
    }

    private const string ValidStation = """
    {
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
    }
    """;

    [Fact]
    public void Maps_greenfield_station_and_current_location_projection()
    {
        var result = GreenfieldStationDirectoryMapper.Map(Payload("[" + ValidStation + "]"));

        Assert.True(result.Succeeded);
        var station = Assert.Single(result.Stations);
        Assert.Equal("NEW-001", station.StationCode);
        Assert.Equal("محطة تجريبية", station.NameAr);
        Assert.Equal("synoptic", station.StationTypeCode);
        Assert.Equal(35.5m, station.Latitude);
        Assert.Equal(36.2m, station.Longitude);
        Assert.Equal("Asia/Damascus", station.TimezoneName);
        Assert.Equal("official_record", station.LocationSource);
        Assert.Empty(result.Issues);
    }

    [Fact]
    public void Allows_missing_optional_location_but_rejects_half_coordinate_pair()
    {
        var withoutLocation = ValidStation
            .Replace("\"latitude\":35.5,", "\"latitude\":null,")
            .Replace("\"longitude\":36.2,", "\"longitude\":null,");
        var valid = GreenfieldStationDirectoryMapper.Map(Payload("[" + withoutLocation + "]"));
        Assert.True(valid.Succeeded);
        Assert.Null(Assert.Single(valid.Stations).Latitude);

        var halfLocation = ValidStation.Replace("\"longitude\":36.2,", "\"longitude\":null,");
        var invalid = GreenfieldStationDirectoryMapper.Map(Payload("[" + halfLocation + "]"));
        Assert.False(invalid.Succeeded);
        Assert.Empty(invalid.Stations);
        Assert.Contains(invalid.Issues, issue => issue.Code == "station_projection_location_invalid");
    }

    [Theory]
    [InlineData("\"approval_status\":\"pending\"")]
    [InlineData("\"operational_status\":\"planned\"")]
    [InlineData("\"operational_status\":\"decommissioned\"")]
    public void Rejects_stations_outside_approved_operational_scope(string replacement)
    {
        var json = ValidStation;
        if (replacement.StartsWith("\"approval_status\"", StringComparison.Ordinal))
            json = json.Replace("\"approval_status\":\"approved\"", replacement);
        else
            json = json.Replace("\"operational_status\":\"active\"", replacement);

        var result = GreenfieldStationDirectoryMapper.Map(Payload("[" + json + "]"));
        Assert.False(result.Succeeded);
        Assert.Empty(result.Stations);
        Assert.Contains(result.Issues, issue => issue.Code == "station_projection_outside_operational_scope");
    }

    [Fact]
    public void Rejects_duplicate_station_id_or_code_to_prevent_join_multiplication()
    {
        var duplicateId = ValidStation.Replace("\"station_code\":\"NEW-001\"", "\"station_code\":\"NEW-002\"");
        var result = GreenfieldStationDirectoryMapper.Map(Payload("[" + ValidStation + "," + duplicateId + "]"));

        Assert.False(result.Succeeded);
        Assert.Empty(result.Stations);
        Assert.Contains(result.Issues, issue => issue.Code == "station_projection_duplicate_identity");
    }

    [Theory]
    [InlineData("\"latitude\":91")]
    [InlineData("\"longitude\":181")]
    [InlineData("\"horizontal_accuracy_m\":-0.1")]
    public void Rejects_invalid_location_values(string replacement)
    {
        var json = ValidStation;
        if (replacement.StartsWith("\"latitude\"", StringComparison.Ordinal))
            json = json.Replace("\"latitude\":35.5", replacement);
        else if (replacement.StartsWith("\"longitude\"", StringComparison.Ordinal))
            json = json.Replace("\"longitude\":36.2", replacement);
        else
            json = json.Replace("\"horizontal_accuracy_m\":4.5", replacement);

        var result = GreenfieldStationDirectoryMapper.Map(Payload("[" + json + "]"));
        Assert.False(result.Succeeded);
        Assert.Contains(result.Issues, issue => issue.Code == "station_projection_location_invalid");
    }

    [Fact]
    public void Rejects_unknown_properties_and_malformed_required_fields()
    {
        var unknown = ValidStation.Replace("\"station_code\":\"NEW-001\",",
            "\"station_code\":\"NEW-001\",\"is_demo\":false,");
        var result = GreenfieldStationDirectoryMapper.Map(Payload("[" + unknown + "]"));
        Assert.False(result.Succeeded);
        Assert.Contains(result.Issues, issue => issue.Code == "station_projection_shape_invalid");

        var malformed = ValidStation.Replace("\"station_code\":\"NEW-001\"", "\"station_code\":\" NEW-001 \"");
        var malformedResult = GreenfieldStationDirectoryMapper.Map(Payload("[" + malformed + "]"));
        Assert.False(malformedResult.Succeeded);
        Assert.Contains(malformedResult.Issues, issue => issue.Code == "station_projection_required_field_invalid");
    }

    [Fact]
    public void Requires_an_array_and_enforces_bounded_result_count()
    {
        Assert.Contains(
            GreenfieldStationDirectoryMapper.Map(Payload("{}")).Issues,
            issue => issue.Code == "station_projection_must_be_array");

        var oversized = "[" + string.Join(",", Enumerable.Repeat(ValidStation,
            GreenfieldStationDirectoryMapper.MaximumStations + 1)) + "]";
        Assert.Contains(
            GreenfieldStationDirectoryMapper.Map(Payload(oversized)).Issues,
            issue => issue.Code == "station_projection_count_out_of_range");
    }
}
