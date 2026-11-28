using Metra.Api.Features.Users;
using Xunit;

namespace Metra.Api.Tests.Features.Users;

public sealed class StationAuditRequestGuardTests
{
    [Fact]
    public void Accepts_non_empty_station_identifier_and_default_limit()
    {
        Assert.Null(StationAuditRequestGuard.GetError(
            Guid.Parse("11111111-1111-4111-8111-111111111111"), 100));
    }

    [Fact]
    public void Rejects_empty_station_identifier()
    {
        Assert.Equal("invalid_station_id",
            StationAuditRequestGuard.GetError(Guid.Empty, 100));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(251)]
    public void Rejects_limits_outside_supported_range(int limit)
    {
        Assert.Equal("invalid_limit",
            StationAuditRequestGuard.GetError(
                Guid.Parse("11111111-1111-4111-8111-111111111111"), limit));
    }

    [Theory]
    [InlineData(1)]
    [InlineData(100)]
    [InlineData(250)]
    public void Accepts_limits_inside_supported_range(int limit)
    {
        Assert.Null(StationAuditRequestGuard.GetError(
            Guid.Parse("11111111-1111-4111-8111-111111111111"), limit));
    }
}
