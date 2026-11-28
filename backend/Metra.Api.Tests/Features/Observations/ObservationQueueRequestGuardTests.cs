using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationQueueRequestGuardTests
{
    [Theory]
    [InlineData(null, null)]
    [InlineData(1, null)]
    [InlineData(50, null)]
    [InlineData(100, null)]
    [InlineData(0, "invalid_limit")]
    [InlineData(-1, "invalid_limit")]
    [InlineData(101, "invalid_limit")]
    public void Queue_limit_is_bounded(int? limit, string? expectedError)
    {
        Assert.Equal(expectedError, ObservationQueueRequestGuard.GetLimitError(limit));
    }
}
