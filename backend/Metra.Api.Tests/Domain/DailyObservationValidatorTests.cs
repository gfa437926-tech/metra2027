using Metra.Api.Domain.Observations;

namespace Metra.Api.Tests;

public sealed class DailyObservationValidatorTests
{
    [Theory]
    [InlineData("minTemp", "-05.3")]
    [InlineData("maxTemp", "25.7")]
    [InlineData("precipitation", "012.5")]
    [InlineData("snowThickness", "015")]
    [InlineData("evaporation", "12.5")]
    [InlineData("sunshineDuration", "08.5")]
    [InlineData("sunshinePercentage", "075")]
    [InlineData("maxGustSpeed", "36")]
    [InlineData("maxGustDirection", "36")]
    [InlineData("maxHumidity", "100")]
    [InlineData("minHumidity", "99")]
    public void Accepts_valid_legacy_daily_field_values(string field, string value)
    {
        var issues = DailyObservationValidator.Validate(new Dictionary<string, string?> { [field] = value });
        Assert.DoesNotContain(issues, issue => issue.Field == field);
    }

    [Theory]
    [InlineData("minTemp", "-25.0")]
    [InlineData("maxTemp", "51.0")]
    [InlineData("precipitation", "1000.0")]
    [InlineData("snowThickness", "1000")]
    [InlineData("sunshineDuration", "24.1")]
    [InlineData("sunshinePercentage", "101")]
    [InlineData("maxGustSpeed", "37")]
    [InlineData("maxHumidity", "101")]
    [InlineData("minHumidity", "100")]
    public void Rejects_values_outside_legacy_field_ranges(string field, string value)
    {
        var issues = DailyObservationValidator.Validate(new Dictionary<string, string?> { [field] = value });
        Assert.Contains(issues, issue => issue.Field == field);
    }

    [Theory]
    [InlineData("#")]
    [InlineData("T")]
    [InlineData("t")]
    public void Accepts_missing_marker_and_precipitation_trace(string value)
    {
        var field = value == "#" ? "minTemp" : "precipitationTrace";
        var issues = DailyObservationValidator.Validate(new Dictionary<string, string?> { [field] = value });
        Assert.Empty(issues);
    }

    [Fact]
    public void Rejects_maximum_temperature_below_minimum_temperature()
    {
        var values = new Dictionary<string, string?>
        {
            ["minTemp"] = "18.0",
            ["maxTemp"] = "17.0"
        };

        var issues = DailyObservationValidator.Validate(values);

        Assert.Contains(issues, issue => issue.Field == "maxTemp");
    }

    [Fact]
    public void Enforces_required_fields_when_supplied_by_report_type()
    {
        var values = new Dictionary<string, string?> { ["minTemp"] = "" };
        var required = new HashSet<string> { "minTemp" };

        var issues = DailyObservationValidator.Validate(values, required);

        Assert.Contains(issues, issue => issue.Field == "minTemp");
    }
}