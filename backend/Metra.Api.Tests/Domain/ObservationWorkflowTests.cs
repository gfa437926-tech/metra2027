using Metra.Api.Domain.Observations;
using Xunit;

namespace Metra.Api.Tests;

public sealed class ObservationWorkflowTests
{
    [Theory]
    [InlineData(ObservationStatus.Draft, ObservationAction.Submit, ObservationStatus.Submitted)]
    [InlineData(ObservationStatus.Returned, ObservationAction.Resubmit, ObservationStatus.Submitted)]
    [InlineData(ObservationStatus.Submitted, ObservationAction.ReturnForCorrection, ObservationStatus.Returned)]
    [InlineData(ObservationStatus.Submitted, ObservationAction.Approve, ObservationStatus.Approved)]
    public void Applies_allowed_transitions(
        ObservationStatus current,
        ObservationAction action,
        ObservationStatus expected)
    {
        var result = ObservationWorkflow.Apply(current, action);

        Assert.True(result.Succeeded);
        Assert.Equal(expected, result.Status);
        Assert.NotNull(result.Transition);
        Assert.Null(result.Issue);
    }

    [Theory]
    [InlineData(ObservationStatus.Draft, ObservationAction.Approve)]
    [InlineData(ObservationStatus.Draft, ObservationAction.ReturnForCorrection)]
    [InlineData(ObservationStatus.Submitted, ObservationAction.Submit)]
    [InlineData(ObservationStatus.Returned, ObservationAction.Approve)]
    [InlineData(ObservationStatus.Approved, ObservationAction.ReturnForCorrection)]
    [InlineData(ObservationStatus.Approved, ObservationAction.Resubmit)]
    public void Rejects_disallowed_transitions(
        ObservationStatus current,
        ObservationAction action)
    {
        var result = ObservationWorkflow.Apply(current, action);

        Assert.False(result.Succeeded);
        Assert.Equal(current, result.Status);
        Assert.Null(result.Transition);
        Assert.Equal("invalid_transition", result.Issue?.Code);
    }

    [Fact]
    public void Approved_observation_is_terminal()
    {
        foreach (var action in Enum.GetValues<ObservationAction>())
        {
            var result = ObservationWorkflow.Apply(ObservationStatus.Approved, action);
            Assert.False(result.Succeeded);
        }
    }
}