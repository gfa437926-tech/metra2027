using System.Text.Json;
using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

/// <summary>
/// Unit-level chain: RequestGuard then DomainValidator, matching endpoint order.
/// Does not call Supabase RPC (no live DB / no service role in tests).
/// </summary>
public sealed class PhenomenonSubmissionGuardChainTests
{
    private static ObservationSubmissionRequest Request(string json, string key = "phenomenon-chain-1")
    {
        var payload = JsonDocument.Parse(json).RootElement.Clone();
        return new ObservationSubmissionRequest(
            key,
            "phenomenon",
            DateTimeOffset.UtcNow,
            payload,
            true);
    }

    [Fact]
    public void Guard_accepts_phenomenon_type()
    {
        var request = Request("""
        {
          "phenomenonType": "fog",
          "phenomenonDate": "2026-11-16",
          "startTime": "08:00:00",
          "responsibilityAgreement": true
        }
        """);

        Assert.Null(ObservationSubmissionRequestGuard.GetError(request));
        Assert.Empty(ObservationSubmissionDomainValidator.Validate(request));
    }

    [Fact]
    public void Guard_rejects_unknown_observation_type()
    {
        using var doc = JsonDocument.Parse("{\"x\":1}");
        var request = new ObservationSubmissionRequest(
            "k",
            "agricultural",
            DateTimeOffset.UtcNow,
            doc.RootElement.Clone(),
            true);

        Assert.Equal("invalid_observation_type", ObservationSubmissionRequestGuard.GetError(request));
    }

    [Fact]
    public void Domain_rejects_before_any_persistence_when_start_time_missing()
    {
        var request = Request("""
        {
          "phenomenonType": "fog",
          "phenomenonDate": "2026-11-16",
          "responsibilityAgreement": true
        }
        """);

        Assert.Null(ObservationSubmissionRequestGuard.GetError(request));
        var issues = ObservationSubmissionDomainValidator.Validate(request);
        Assert.Contains(issues, i => i.Field is "start_time" or "startTime");
    }

    [Fact]
    public void Domain_rejects_missing_responsibility_agreement_on_submit_path()
    {
        var request = Request("""
        {
          "phenomenonType": "fog",
          "phenomenonDate": "2026-11-16",
          "startTime": "08:00:00"
        }
        """);

        var issues = ObservationSubmissionDomainValidator.Validate(request);
        Assert.Contains(issues, i => i.Field == "responsibilityAgreement");
    }

    [Fact]
    public void Same_idempotency_key_shape_is_accepted_by_guard()
    {
        var request = Request("""
        {
          "phenomenonType": "rain",
          "phenomenonDate": "2026-11-16",
          "startTime": "09:00:00",
          "endTime": "10:00:00",
          "responsibilityAgreement": true
        }
        """, key: "phenomenon-station-fixed-key");

        Assert.Null(ObservationSubmissionRequestGuard.GetError(request));
        Assert.Empty(ObservationSubmissionDomainValidator.Validate(request));
    }
}
