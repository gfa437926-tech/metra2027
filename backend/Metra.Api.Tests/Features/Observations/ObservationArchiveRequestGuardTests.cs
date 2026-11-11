using Metra.Api.Features.Observations;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationArchiveRequestGuardTests
{
    [Fact]
    public void AcceptsSupportedTypesAndUtcRange()
    {
        var from = new DateTimeOffset(2026, 11, 1, 0, 0, 0, TimeSpan.Zero);
        var to = new DateTimeOffset(2026, 11, 2, 0, 0, 0, TimeSpan.Zero);

        Assert.Null(ObservationArchiveRequestGuard.GetError(
            "hourly", from, to, 50, 0));
    }

    [Theory]
    [InlineData("unknown", "invalid_observation_type")]
    [InlineData("HOURLY", "invalid_observation_type")]
    public void RejectsUnsupportedObservationTypes(string type, string expected)
    {
        Assert.Equal(expected, ObservationArchiveRequestGuard.GetError(
            type, null, null, null, null));
    }

    [Fact]
    public void RejectsNonUtcOffsetsRatherThanSilentlyConvertingThem()
    {
        var local = new DateTimeOffset(2026, 11, 1, 3, 0, 0, TimeSpan.FromHours(3));

        Assert.Equal("utc_offset_required", ObservationArchiveRequestGuard.GetError(
            null, local, null, null, null));
    }

    [Fact]
    public void RejectsEmptyOrReversedTimeRange()
    {
        var from = new DateTimeOffset(2026, 11, 2, 0, 0, 0, TimeSpan.Zero);
        var to = new DateTimeOffset(2026, 11, 2, 0, 0, 0, TimeSpan.Zero);

        Assert.Equal("invalid_time_range", ObservationArchiveRequestGuard.GetError(
            null, from, to, null, null));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(101)]
    public void RejectsOutOfRangePageSize(int limit)
    {
        Assert.Equal("invalid_limit", ObservationArchiveRequestGuard.GetError(
            null, null, null, limit, null));
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(100001)]
    public void RejectsOutOfRangeOffset(int offset)
    {
        Assert.Equal("invalid_offset", ObservationArchiveRequestGuard.GetError(
            null, null, null, null, offset));
    }

    [Fact]
    public void AcceptsAllVerifiedImportedArchiveTypes()
    {
        var types = new[]
        {
            "daily", "hourly", "climate", "soil",
            "agricultural", "phenomenon", "fieldclimate"
        };

        Assert.All(types, type =>
            Assert.Null(ObservationArchiveRequestGuard.GetError(
                type, null, null, 50, 0)));
    }
}
