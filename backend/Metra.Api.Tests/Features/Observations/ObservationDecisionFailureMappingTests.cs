using System.Net;
using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationDecisionFailureMappingTests
{
    [Theory]
    [InlineData("self_review_forbidden", HttpStatusCode.Conflict)]
    [InlineData("ERROR: self_review_forbidden", HttpStatusCode.Conflict)]
    [InlineData("observation_not_found", HttpStatusCode.NotFound)]
    [InlineData("observation_not_in_submitted_state", HttpStatusCode.Conflict)]
    [InlineData("station_observation_decision_forbidden", HttpStatusCode.Forbidden)]
    [InlineData("decision_note_required", HttpStatusCode.BadRequest)]
    [InlineData("invalid_observation_decision", HttpStatusCode.BadRequest)]
    public void Maps_database_messages_to_stable_http_codes(string body, HttpStatusCode expected)
    {
        Assert.Equal(
            expected,
            SupabaseObservationDecisionService.MapDecisionFailure(body, HttpStatusCode.InternalServerError));
    }

    [Fact]
    public void Falls_closed_to_service_unavailable_for_unknown_server_errors()
    {
        Assert.Equal(
            HttpStatusCode.ServiceUnavailable,
            SupabaseObservationDecisionService.MapDecisionFailure("boom", HttpStatusCode.InternalServerError));
    }
}
