using System.Text.Json;
using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationSubmissionPayloadValidatorTests
{
    private static ObservationSubmissionRequest Request(string type, string payload)
    {
        using var json = JsonDocument.Parse(payload);
        return new("req-001", type, DateTimeOffset.Parse("2026-11-13T12:00:00Z"),
            json.RootElement.Clone(), true);
    }

    [Fact]
    public void Hourly_submission_requires_source_contract_fields()
    {
        var issues = ObservationSubmissionPayloadValidator.Validate(
            Request("hourly", """{"dryTemp":"+20.0"}"""));
        Assert.Contains(issues, issue => issue.Field == "utcTime");
        Assert.Contains(issues, issue => issue.Field == "stationPressure");
    }

    [Fact]
    public void Daily_submission_requires_explicit_report_type_and_full_24_hour_fields()
    {
        var missingType = ObservationSubmissionPayloadValidator.Validate(
            Request("daily", """{"minTemp":"05.0","maxTemp":"20.0"}"""));
        Assert.Contains(missingType, issue => issue.Field == "reportType");

        var missingFields = ObservationSubmissionPayloadValidator.Validate(
            Request("daily", """{"reportType":"24h","minTemp":"05.0","maxTemp":"20.0"}"""));
        Assert.Contains(missingFields, issue => issue.Field == "precipitation");
        Assert.Contains(missingFields, issue => issue.Field == "maxHumidityTime");
    }

    [Theory]
    [InlineData("06utc")]
    [InlineData("18utc")]
    public void Daily_synoptic_reports_fail_closed_until_source_conflict_is_resolved(string reportType)
    {
        var issues = ObservationSubmissionPayloadValidator.Validate(
            Request("daily", $$"""{"reportType":"{{reportType}}"}"""));
        Assert.Contains(issues, issue => issue.Field == "reportType");
    }

    [Fact]
    public void Client_cannot_supply_server_owned_identity_or_workflow_fields()
    {
        var issues = ObservationSubmissionPayloadValidator.Validate(
            Request("hourly", """{"user_id":"attacker","station_id":"other-station"}"""));
        Assert.Contains(issues, issue => issue.Field == "user_id");
        Assert.Contains(issues, issue => issue.Field == "station_id");
    }
}
