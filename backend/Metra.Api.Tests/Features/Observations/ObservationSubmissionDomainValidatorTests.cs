using System.Text.Json;
using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationSubmissionDomainValidatorTests
{
    [Fact]
    public void Daily_submission_is_checked_using_catalogue_required_fields_and_legacy_format()
    {
        using var payload = JsonDocument.Parse("""
        {
          "currentDate":"2026-11-16",
          "minTemp":5.2,
          "maxTemp":20.3,
          "precipitation":2.1,
          "snowThickness":0,
          "evaporation":1.2,
          "sunshineDuration":8.0,
          "sunshinePercentage":50,
          "maxGustSpeed":10,
          "maxGustDirection":18,
          "maxGustTime":14.0,
          "maxHumidity":90,
          "maxHumidityTime":6.0,
          "minHumidity":20,
          "minHumidityTime":14.0,
          "responsibilityAgreement":true
        }
        """);
        var request = new ObservationSubmissionRequest(
            "daily-test-key", "daily", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Empty(issues);
    }

    [Fact]
    public void Daily_submission_rejects_invalid_temperature_relationship()
    {
        using var payload = JsonDocument.Parse("""
        {
          "currentDate":"2026-11-16",
          "minTemp":21.0,
          "maxTemp":20.0,
          "precipitation":2.1,
          "snowThickness":0,
          "evaporation":1.2,
          "sunshineDuration":8.0,
          "sunshinePercentage":50,
          "maxGustSpeed":10,
          "maxGustDirection":18,
          "maxGustTime":14.0,
          "maxHumidity":90,
          "maxHumidityTime":6.0,
          "minHumidity":20,
          "minHumidityTime":14.0,
          "responsibilityAgreement":true
        }
        """);
        var request = new ObservationSubmissionRequest(
            "daily-test-key", "daily", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Contains(issues, issue => issue.Field == "maxTemp");
    }

    [Fact]
    public void Hourly_submission_is_checked_using_utc_hour_and_fixed_width_codes()
    {
        using var payload = JsonDocument.Parse("""
        {
          "utcTime":"00",
          "dryTemp":15.2,
          "wetTemp":10.1,
          "stationPressure":1000.0,
          "seaLevelPressure":1010.0,
          "relativeHumidity":50,
          "dewPoint":5.1,
          "windDirection":18,
          "windSpeed":3,
          "visibility":10,
          "totalCloudCover":4,
          "cover12":4,
          "cover123":4,
          "precipitationAmount":0.0,
          "pressureSlope":0.0,
          "pressureShape":0,
          "pastWeather":0,
          "responsibilityAgreement":true
        }
        """);
        var request = new ObservationSubmissionRequest(
            "hourly-test-key", "hourly", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Empty(issues);
    }

    [Fact]
    public void Hourly_submission_rejects_wet_temperature_above_dry_temperature()
    {
        using var payload = JsonDocument.Parse("""
        {
          "utcTime":"03",
          "dryTemp":8.0,
          "wetTemp":10.0,
          "stationPressure":1000.0,
          "seaLevelPressure":1010.0,
          "relativeHumidity":50,
          "dewPoint":5.1,
          "windDirection":18,
          "windSpeed":3,
          "visibility":10,
          "totalCloudCover":4,
          "cover12":4,
          "cover123":4,
          "pressureSlope":0.0,
          "pressureShape":0,
          "pastWeather":0,
          "responsibilityAgreement":true
        }
        """);
        var request = new ObservationSubmissionRequest(
            "hourly-test-key", "hourly", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Contains(issues, issue => issue.Field == "dryTemp");
    }

    [Fact]
    public void Submission_requires_explicit_responsibility_confirmation()
    {
        using var payload = JsonDocument.Parse("""
        {
          "currentDate":"2026-11-16",
          "minTemp":5.2,
          "maxTemp":20.3,
          "precipitation":2.1,
          "snowThickness":0,
          "evaporation":1.2,
          "sunshineDuration":8.0,
          "sunshinePercentage":50,
          "maxGustSpeed":10,
          "maxGustDirection":18,
          "maxGustTime":14.0,
          "maxHumidity":90,
          "maxHumidityTime":6.0,
          "minHumidity":20,
          "minHumidityTime":14.0,
          "responsibilityAgreement":false
        }
        """);
        var request = new ObservationSubmissionRequest(
            "daily-test-key", "daily", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Contains(issues, issue => issue.Field == "responsibilityAgreement");
    }

    [Fact]
    public void Phenomenon_submission_fails_closed_until_its_domain_contract_is_connected()
    {
        using var payload = JsonDocument.Parse("""{"code":"rain"}""");
        var request = new ObservationSubmissionRequest(
            "phenomenon-test-key", "phenomenon", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Contains(issues, issue => issue.Field == "observationType");
    }
}
