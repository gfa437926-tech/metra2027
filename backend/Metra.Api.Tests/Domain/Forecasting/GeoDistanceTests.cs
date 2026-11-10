using Metra.Api.Domain.Forecasting;
using Xunit;

namespace Metra.Api.Tests.Domain.Forecasting;

public sealed class GeoDistanceTests
{
    [Fact]
    public void Haversine_returns_null_when_any_coordinate_missing()
    {
        Assert.Null(GeoDistance.HaversineKm(null, 13.0, 32.0, 13.1));
        Assert.Null(GeoDistance.HaversineKm(32.0, 13.0, null, 13.1));
    }

    [Fact]
    public void Haversine_returns_null_for_invalid_latitude()
    {
        Assert.Null(GeoDistance.HaversineKm(95.0, 13.0, 32.0, 13.1));
    }

    [Fact]
    public void Haversine_computes_positive_distance_for_distinct_valid_points()
    {
        var km = GeoDistance.HaversineKm(32.9, 13.2, 32.1, 20.1);
        Assert.NotNull(km);
        Assert.True(km > 100);
        Assert.True(km < 2000);
    }

    [Fact]
    public void Haversine_is_near_zero_for_identical_points()
    {
        var km = GeoDistance.HaversineKm(32.8872, 13.1913, 32.8872, 13.1913);
        Assert.NotNull(km);
        Assert.True(km is >= 0 and < 0.001);
    }
}
