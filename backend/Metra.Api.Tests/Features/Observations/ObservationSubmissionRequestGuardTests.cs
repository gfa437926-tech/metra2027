using System.Text.Json;
using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationSubmissionRequestGuardTests
{
    private static ObservationSubmissionRequest ValidRequest(
        string? key = "req-001",
        string? type = "daily",
        DateTimeOffset? observedAt = null,
        string payload = "{\"tmax\":31.2}")
    {
        using var document = JsonDocument.Parse(payload);
        return new ObservationSubmissionRequest(
            key, type, observedAt ?? DateTimeOffset.Parse("2026-11-03T12:00:00Z"),
            document.RootElement.Clone(), false);
    }

    [Fact]
    public void Accepts_a_well_formed_submission()
        => Assert.Null(ObservationSubmissionRequestGuard.GetError(ValidRequest()));

    [Fact]
    public void Rejects_missing_or_padded_idempotency_key()
    {
        Assert.Equal("invalid_idempotency_key",
            ObservationSubmissionRequestGuard.GetError(ValidRequest(key: null)));
        Assert.Equal("invalid_idempotency_key",
            ObservationSubmissionRequestGuard.GetError(ValidRequest(key: " req-001 ")));
    }

    [Fact]
    public void Rejects_unknown_observation_type()
        => Assert.Equal("invalid_observation_type",
            ObservationSubmissionRequestGuard.GetError(ValidRequest(type: "climate")));

    [Fact]
    public void Rejects_non_object_payload()
        => Assert.Equal("invalid_observation_payload",
            ObservationSubmissionRequestGuard.GetError(ValidRequest(payload: "[1,2,3]")));

    [Fact]
    public void Rejects_missing_observation_time()
    {
        using var document = JsonDocument.Parse("{\"tmax\":31.2}");
        var request = new ObservationSubmissionRequest(
            "req-001", "daily", null, document.RootElement.Clone());
        Assert.Equal("invalid_observation_payload",
            ObservationSubmissionRequestGuard.GetError(request));
    }
}
