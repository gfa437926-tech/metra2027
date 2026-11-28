using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationDecisionRequestGuardTests
{
    [Theory]
    [InlineData(null, null, true)]
    [InlineData("", null, true)]
    [InlineData("approve", null, false)]
    [InlineData("return_for_correction", "سبب واضح", false)]
    [InlineData("return_for_correction", null, true)]
    [InlineData("return_for_correction", "   ", true)]
    [InlineData("approve", " سبب ", true)]
    [InlineData("reject", null, true)]
    [InlineData("approve", "x", false)]
    public void Decision_endpoint_validation_accepts_only_supported_decisions_and_bounded_notes(
        string? decision, string? note, bool expectedError)
    {
        var request = decision is null && note is null ? null : new ObservationDecisionRequest(decision, note);
        var actualError = ObservationDecisionRequestGuard.GetError(request);
        Assert.Equal(expectedError, actualError is not null);
    }

    [Fact]
    public void Decision_note_over_2000_characters_is_rejected()
    {
        var request = new ObservationDecisionRequest("approve", new string('x', 2001));
        Assert.Equal("decision_note_too_long", ObservationDecisionRequestGuard.GetError(request));
    }

    [Fact]
    public void Decision_note_at_2000_characters_is_accepted()
    {
        var request = new ObservationDecisionRequest("approve", new string('x', 2000));
        Assert.Null(ObservationDecisionRequestGuard.GetError(request));
    }

    [Theory]
    [InlineData("approve", " note ")]
    [InlineData("return_for_correction", " سبب ")]
    public void Decision_note_with_surrounding_whitespace_is_rejected(string decision, string note)
    {
        var request = new ObservationDecisionRequest(decision, note);
        Assert.Equal("invalid_decision_note", ObservationDecisionRequestGuard.GetError(request));
    }

    [Fact]
    public void Correction_note_is_required_even_when_empty_string()
    {
        var request = new ObservationDecisionRequest("return_for_correction", string.Empty);
        Assert.Equal("decision_note_required", ObservationDecisionRequestGuard.GetError(request));
    }
}
