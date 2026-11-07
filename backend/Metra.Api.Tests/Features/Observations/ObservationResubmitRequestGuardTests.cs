using System.Text.Json;
using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationResubmitRequestGuardTests
{
    [Fact]
    public void Accepts_null_or_object_payload()
    {
        Assert.Null(ObservationResubmitRequestGuard.GetError(null));
        Assert.Null(ObservationResubmitRequestGuard.GetError(new ObservationResubmitRequest(null)));
        using var doc = JsonDocument.Parse("{\"dry_temp\":\"21.0\"}");
        Assert.Null(ObservationResubmitRequestGuard.GetError(
            new ObservationResubmitRequest(doc.RootElement.Clone())));
    }

    [Fact]
    public void Rejects_non_object_payload()
    {
        using var doc = JsonDocument.Parse("[1,2,3]");
        Assert.Equal(
            "invalid_observation_payload",
            ObservationResubmitRequestGuard.GetError(
                new ObservationResubmitRequest(doc.RootElement.Clone())));
    }
}

public sealed class ObservationResubmitFailureMappingTests
{
    [Theory]
    [InlineData("not_observation_owner", System.Net.HttpStatusCode.Forbidden)]
    [InlineData("observation_not_found", System.Net.HttpStatusCode.NotFound)]
    [InlineData("observation_not_in_returned_state", System.Net.HttpStatusCode.Conflict)]
    [InlineData("station_observation_submit_forbidden", System.Net.HttpStatusCode.Forbidden)]
    [InlineData("invalid_observation_payload", System.Net.HttpStatusCode.BadRequest)]
    public void Maps_database_messages(string body, System.Net.HttpStatusCode expected)
    {
        Assert.Equal(
            expected,
            SupabaseObservationResubmitService.MapResubmitFailure(body, System.Net.HttpStatusCode.InternalServerError));
    }
}
