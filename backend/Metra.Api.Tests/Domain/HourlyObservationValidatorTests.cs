using Metra.Api.Domain.Observations;
using Xunit;

namespace Metra.Api.Tests;

public sealed class HourlyObservationValidatorTests
{
    private static Dictionary<string, string?> ValidReport(string hour = "01") => new()
    {
        ["utcTime"] = hour,
        ["dryTemp"] = "+25.0",
        ["wetTemp"] = "+20.0",
        ["stationPressure"] = "1013.2",
        ["seaLevelPressure"] = "1013.2",
        ["windDirection"] = "18",
        ["windSpeed"] = "12",
        ["visibility"] = "050",
        ["totalCloudCover"] = "4",
        ["relativeHumidity"] = "065",
        ["dewPoint"] = "+18.5",
        ["cover12"] = "4",
        ["cover123"] = "5"
    };

    [Fact]
    public void Accepts_valid_hourly_report_at_non_synoptic_hour()
    {
        var issues = HourlyObservationValidator.Validate(ValidReport());
        Assert.Empty(issues);
    }

    [Theory]
    [InlineData("00")]
    [InlineData("06")]
    [InlineData("12")]
    [InlineData("18")]
    public void Requires_precipitation_at_six_hour_synoptic_times(string hour)
    {
        var values = ValidReport(hour);
        values["pressureSlope"] = "2.3";
        values["pressureShape"] = "5";
        values["pastWeather"] = "0";

        var issues = HourlyObservationValidator.Validate(values);

        Assert.Contains(issues, issue => issue.Field == "precipitationAmount");
    }

    [Theory]
    [InlineData("03")]
    [InlineData("09")]
    [InlineData("15")]
    [InlineData("21")]
    public void Requires_pressure_characteristics_and_past_weather_at_three_hour_times(string hour)
    {
        var issues = HourlyObservationValidator.Validate(ValidReport(hour));

        Assert.Contains(issues, issue => issue.Field == "pressureSlope");
        Assert.Contains(issues, issue => issue.Field == "pressureShape");
        Assert.Contains(issues, issue => issue.Field == "pastWeather");
    }

    [Fact]
    public void Rejects_dry_temperature_lower_than_wet_temperature()
    {
        var values = ValidReport();
        values["dryTemp"] = "+18.0";
        values["wetTemp"] = "+20.0";

        var issues = HourlyObservationValidator.Validate(values);

        Assert.Contains(issues, issue => issue.Field == "dryTemp");
    }

    [Theory]
    [InlineData("-01")]
    [InlineData("24")]
    [InlineData("abc")]
    public void Rejects_invalid_utc_hours(string hour)
    {
        var issues = HourlyObservationValidator.Validate(ValidReport(hour));
        Assert.Contains(issues, issue => issue.Field == "utcTime");
    }

    [Fact]
    public void Accepts_hash_missing_marker_for_hourly_values()
    {
        var values = ValidReport();
        values["dryTemp"] = "#";

        var issues = HourlyObservationValidator.Validate(values);

        Assert.DoesNotContain(issues, issue => issue.Field == "dryTemp");
    }

    [Fact]
    public void Rejects_invalid_pressure_and_humidity_ranges()
    {
        var values = ValidReport();
        values["stationPressure"] = "0700.0";
        values["relativeHumidity"] = "000";

        var issues = HourlyObservationValidator.Validate(values);

        Assert.Contains(issues, issue => issue.Field == "stationPressure");
        Assert.Contains(issues, issue => issue.Field == "relativeHumidity");
    }
}