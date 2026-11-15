using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationArchiveTimeRangeGuardTests
{
    private static readonly DateTime UtcStart =
        new(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);
    private static readonly DateTime UtcEnd =
        new(2026, 1, 2, 0, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void Accepts_explicit_utc_bounds()
    {
        Assert.Null(ObservationArchiveTimeRangeGuard.GetError(UtcStart, UtcEnd));
    }

    [Fact]
    public void Allows_either_bound_to_be_omitted()
    {
        Assert.Null(ObservationArchiveTimeRangeGuard.GetError(null, UtcEnd));
        Assert.Null(ObservationArchiveTimeRangeGuard.GetError(UtcStart, null));
        Assert.Null(ObservationArchiveTimeRangeGuard.GetError(null, null));
    }

    [Fact]
    public void Rejects_unspecified_from_bound()
    {
        var unspecified = DateTime.SpecifyKind(UtcStart, DateTimeKind.Unspecified);
        Assert.Equal("archive_from_must_be_utc",
            ObservationArchiveTimeRangeGuard.GetError(unspecified, UtcEnd));
    }

    [Fact]
    public void Rejects_local_to_bound()
    {
        var local = DateTime.SpecifyKind(UtcEnd, DateTimeKind.Local);
        Assert.Equal("archive_to_must_be_utc",
            ObservationArchiveTimeRangeGuard.GetError(UtcStart, local));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void Rejects_empty_or_reversed_utc_ranges(int dayOffset)
    {
        var end = UtcStart.AddDays(dayOffset);
        Assert.Equal("invalid_archive_date_range",
            ObservationArchiveTimeRangeGuard.GetError(UtcStart, end));
    }
}
