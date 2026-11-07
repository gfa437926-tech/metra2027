using Metra.Api.Features.EquipmentFaults;
using Xunit;

namespace Metra.Api.Tests.EquipmentFaults;

public sealed class EquipmentFaultTransitionConcurrencyTests
{
    [Theory]
    [InlineData(EquipmentFaultStatus.Submitted, EquipmentFaultStatus.Submitted, true)]
    [InlineData(EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview, false)]
    [InlineData(EquipmentFaultStatus.Resolved, EquipmentFaultStatus.Resolved, true)]
    [InlineData(EquipmentFaultStatus.Closed, EquipmentFaultStatus.Closed, true)]
    [InlineData(EquipmentFaultStatus.Rejected, EquipmentFaultStatus.Rejected, true)]
    public void Expected_status_must_match_the_persisted_status(
        EquipmentFaultStatus expected,
        EquipmentFaultStatus persisted,
        bool matches)
    {
        Assert.Equal(matches,
            EquipmentFaultTransitionConcurrency.MatchesExpectedStatus(expected, persisted));
    }

    [Theory]
    [InlineData((EquipmentFaultStatus)999, EquipmentFaultStatus.Submitted)]
    [InlineData(EquipmentFaultStatus.Submitted, (EquipmentFaultStatus)999)]
    [InlineData((EquipmentFaultStatus)999, (EquipmentFaultStatus)999)]
    public void Undefined_status_values_never_match(
        EquipmentFaultStatus expected,
        EquipmentFaultStatus persisted)
    {
        Assert.False(EquipmentFaultTransitionConcurrency.MatchesExpectedStatus(
            expected, persisted));
    }
}
