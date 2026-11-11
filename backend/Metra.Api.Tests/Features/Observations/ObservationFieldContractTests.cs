using System.Text.Json;
using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationFieldContractTests
{
    [Theory]
    [InlineData("24h", 13)]
    [InlineData("06utc", 3)]
    [InlineData("18utc", 3)]
    public void Daily_contract_exposes_report_type_specific_required_fields(string type, int count)
    {
        var fields = ObservationFieldContract.GetDailyRequiredFields(type);
        Assert.Equal(count, fields.Count);
    }

    [Fact]
    public void Daily_contract_rejects_unknown_report_type()
    {
        using var document = JsonDocument.Parse("""
        {
          "reportType": "weekly",
          "responsibilityAgreement": true,
          "values": {}
        }
        """);

        var issues = ObservationFieldContract.ValidateSubmission("daily", document.RootElement);

        Assert.Contains(issues, issue => issue.Field == "reportType");
    }

    [Fact]
    public void Daily_contract_requires_responsibility_acknowledgement()
    {
        using var document = JsonDocument.Parse("""
        {
          "reportType": "06utc",
          "responsibilityAgreement": false,
          "values": {
            "minTemp": "-05.3",
            "maxTemp": "25.7",
            "precipitation": "012.5",
            "snowThickness": "015"
          }
        }
        """);

        var issues = ObservationFieldContract.ValidateSubmission("daily", document.RootElement);

        Assert.Contains(issues, issue => issue.Field == "responsibilityAgreement");
    }

    [Fact]
    public void Daily_contract_accepts_complete_06utc_payload()
    {
        using var document = JsonDocument.Parse("""
        {
          "reportType": "06utc",
          "responsibilityAgreement": true,
          "values": {
            "minTemp": "-05.3",
            "maxTemp": "25.7",
            "precipitation": "012.5",
            "snowThickness": "015"
          }
        }
        """);

        var issues = ObservationFieldContract.ValidateSubmission("daily", document.RootElement);

        Assert.Empty(issues);
    }

    [Fact]
    public void Daily_submission_contract_rejects_minimum_humidity_above_maximum()
    {
        using var document = JsonDocument.Parse("""
        {
          "reportType": "06utc",
          "responsibilityAgreement": true,
          "values": {
            "minTemp": "-05.3",
            "maxTemp": "25.7",
            "precipitation": "012.5",
            "snowThickness": "015",
            "maxHumidity": "060",
            "minHumidity": "75"
          }
        }
        """);

        var issues = ObservationFieldContract.ValidateSubmission("daily", document.RootElement);

        Assert.Contains(issues, issue => issue.Field == "minHumidity");
    }

    [Fact]
    public void Daily_24_hour_contract_requires_full_phenomena_and_sunshine_fields()
    {
        using var document = JsonDocument.Parse("""
        {
          "reportType": "24h",
          "responsibilityAgreement": true,
          "values": {
            "minTemp": "-05.3",
            "maxTemp": "25.7",
            "precipitation": "012.5",
            "snowThickness": "015"
          }
        }
        """);

        var issues = ObservationFieldContract.ValidateSubmission("daily", document.RootElement);

        Assert.Contains(issues, issue => issue.Field == "evaporation");
        Assert.Contains(issues, issue => issue.Field == "sunshineDuration");
        Assert.Contains(issues, issue => issue.Field == "maxGustSpeed");
        Assert.Contains(issues, issue => issue.Field == "maxHumidity");
    }

    [Fact]
    public void Hourly_contract_uses_utc_hour_for_conditional_fields()
    {
        using var document = JsonDocument.Parse("""
        {
          "utcHour": "00",
          "values": {
            "utcTime": "00",
            "dryTemp": "+25.0",
            "wetTemp": "+20.0",
            "stationPressure": "1013.2",
            "seaLevelPressure": "1013.2",
            "windDirection": "18",
            "windSpeed": "12",
            "visibility": "050",
            "totalCloudCover": "4",
            "relativeHumidity": "065",
            "dewPoint": "+18.5",
            "cover12": "4",
            "cover123": "5"
          }
        }
        """);

        var issues = ObservationFieldContract.ValidateSubmission("hourly", document.RootElement);

        Assert.Contains(issues, issue => issue.Field == "precipitationAmount");
        Assert.Contains(issues, issue => issue.Field == "pressureSlope");
        Assert.Contains(issues, issue => issue.Field == "pressureShape");
        Assert.Contains(issues, issue => issue.Field == "pastWeather");
    }

    [Fact]
    public void Contract_rejects_non_string_field_values()
    {
        using var document = JsonDocument.Parse("""
        {
          "values": {
            "utcTime": "01",
            "dryTemp": 25
          }
        }
        """);

        var issues = ObservationFieldContract.ValidateSubmission("hourly", document.RootElement);

        Assert.Contains(issues, issue => issue.Field == "dryTemp");
    }
}
