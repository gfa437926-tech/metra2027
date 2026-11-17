using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationSubmissionFeatureGateTests
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("false")]
    [InlineData("0")]
    [InlineData("yes")]
    public void Missing_or_unrecognized_approval_keeps_writes_disabled(string? configuredValue)
    {
        Assert.False(ObservationSubmissionFeatureGate.IsEnabled(configuredValue));
    }

    [Fact]
    public void Explicit_true_enables_writes_after_scientific_approval()
    {
        Assert.True(ObservationSubmissionFeatureGate.IsEnabled("true"));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("false")]
    [InlineData("0")]
    [InlineData("yes")]
    public void Missing_or_unrecognized_atomic_decision_approval_keeps_decisions_disabled(string? configuredValue)
    {
        Assert.False(ObservationDecisionFeatureGate.IsEnabled(configuredValue));
    }

    [Fact]
    public void Explicit_true_enables_decisions_after_atomic_authorization_deployment()
    {
        Assert.True(ObservationDecisionFeatureGate.IsEnabled("true"));
    }
}
