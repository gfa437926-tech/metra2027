using System.Text.Json;
using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class PhenomenonSubmissionDomainValidatorTests
{
    [Fact]
    public void Valid_phenomenon_payload_passes_domain_validation()
    {
        using var payload = JsonDocument.Parse("""
        {
          "phenomenonType": "dust_storm",
          "phenomenonDate": "2026-11-16",
          "startTime": "08:15:00",
          "endTime": "10:30:00",
          "generalNotes": "عاصفة غبارية محلية",
          "responsibilityAgreement": true
        }
        """);
        var request = new ObservationSubmissionRequest(
            "phenomenon-ok-1", "phenomenon", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Empty(issues);
    }

    [Fact]
    public void Active_phenomenon_without_end_time_is_allowed()
    {
        using var payload = JsonDocument.Parse("""
        {
          "phenomenonType": "fog",
          "phenomenonDate": "2026-11-16",
          "startTime": "05:00:00",
          "responsibilityAgreement": true
        }
        """);
        var request = new ObservationSubmissionRequest(
            "phenomenon-active-1", "phenomenon", DateTimeOffset.UtcNow, payload.RootElement, true);

        Assert.Empty(ObservationSubmissionDomainValidator.Validate(request));
    }

    [Fact]
    public void Missing_required_fields_are_reported()
    {
        using var payload = JsonDocument.Parse("""{"responsibilityAgreement":true}""");
        var request = new ObservationSubmissionRequest(
            "phenomenon-missing", "phenomenon", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Contains(issues, i => i.Field is "phenomenon_type" or "phenomenonType");
        Assert.Contains(issues, i => i.Field is "phenomenon_date" or "phenomenonDate");
        Assert.Contains(issues, i => i.Field is "start_time" or "startTime");
    }

    [Fact]
    public void Invalid_date_and_time_formats_are_rejected()
    {
        using var payload = JsonDocument.Parse("""
        {
          "phenomenonType": "hail",
          "phenomenonDate": "16/11/2026",
          "startTime": "8:15",
          "endTime": "not-a-time",
          "responsibilityAgreement": true
        }
        """);
        var request = new ObservationSubmissionRequest(
            "phenomenon-fmt", "phenomenon", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Contains(issues, i => i.Field is "phenomenon_date" or "phenomenonDate");
        Assert.Contains(issues, i => i.Field is "start_time" or "startTime");
        Assert.Contains(issues, i => i.Field is "end_time" or "endTime");
    }

    [Fact]
    public void End_time_before_start_time_is_rejected()
    {
        using var payload = JsonDocument.Parse("""
        {
          "phenomenonType": "rain",
          "phenomenonDate": "2026-11-16",
          "startTime": "12:00:00",
          "endTime": "11:00:00",
          "responsibilityAgreement": true
        }
        """);
        var request = new ObservationSubmissionRequest(
            "phenomenon-order", "phenomenon", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Contains(issues, i => i.Field is "end_time" or "endTime");
    }

    [Fact]
    public void Phenomenon_type_longer_than_64_chars_is_rejected()
    {
        var longType = new string('x', 65);
        using var payload = JsonDocument.Parse($$"""
        {
          "phenomenonType": "{{longType}}",
          "phenomenonDate": "2026-11-16",
          "startTime": "09:00:00",
          "responsibilityAgreement": true
        }
        """);
        var request = new ObservationSubmissionRequest(
            "phenomenon-long", "phenomenon", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Contains(issues, i => i.Field is "phenomenon_type" or "phenomenonType");
    }

    [Fact]
    public void Nested_payload_values_are_rejected()
    {
        using var payload = JsonDocument.Parse("""
        {
          "phenomenonType": "fog",
          "phenomenonDate": "2026-11-16",
          "startTime": "06:00:00",
          "meta": { "source": "manual" },
          "responsibilityAgreement": true
        }
        """);
        var request = new ObservationSubmissionRequest(
            "phenomenon-nested", "phenomenon", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Contains(issues, i => i.Field == "meta");
    }

    [Fact]
    public void Missing_responsibility_agreement_fails_closed()
    {
        using var payload = JsonDocument.Parse("""
        {
          "phenomenonType": "fog",
          "phenomenonDate": "2026-11-16",
          "startTime": "06:00:00"
        }
        """);
        var request = new ObservationSubmissionRequest(
            "phenomenon-no-ack", "phenomenon", DateTimeOffset.UtcNow, payload.RootElement, true);

        var issues = ObservationSubmissionDomainValidator.Validate(request);

        Assert.Contains(issues, i => i.Field == "responsibilityAgreement");
    }

    [Fact]
    public void Snake_case_keys_are_accepted()
    {
        using var payload = JsonDocument.Parse("""
        {
          "phenomenon_type": "thunderstorm",
          "phenomenon_date": "2026-11-16",
          "start_time": "14:00:00",
          "end_time": "15:30:00",
          "general_notes": "رعد محلي",
          "responsibility_agreement": true
        }
        """);
        var request = new ObservationSubmissionRequest(
            "phenomenon-snake", "phenomenon", DateTimeOffset.UtcNow, payload.RootElement, true);

        Assert.Empty(ObservationSubmissionDomainValidator.Validate(request));
    }
}
