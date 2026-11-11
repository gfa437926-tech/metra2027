using System.Text.Json;
using Metra.Api.Domain.Forecasting;
using Xunit;

namespace Metra.Api.Tests.Domain.Forecasting;

public sealed class WeatherObservationSnapshotMapperTests
{
    [Fact]
    public void Missing_hourly_fields_remain_null_not_zero()
    {
        using var doc = JsonDocument.Parse("""{"values":{"utcTime":"12","dryTemp":"+21.0"}}""");
        var snap = WeatherObservationSnapshotMapper.FromHourlyPayload(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "approved",
            DateTimeOffset.Parse("2026-11-10T12:00:00Z"),
            DateTimeOffset.Parse("2026-11-10T12:05:00Z"),
            doc.RootElement);

        Assert.Equal("+21.0", snap.Elements.DryTemp);
        Assert.Null(snap.Elements.Visibility);
        Assert.Null(snap.Elements.WindSpeed);
        Assert.Null(snap.Elements.PrecipitationAmount);
        Assert.True(snap.Elements.Visibility is null || snap.Elements.Visibility != "0");
        Assert.Equal("unknown_policy", snap.Freshness);
        Assert.Contains("DryTemp", snap.FieldProvenance.Keys);
    }

    [Fact]
    public void Empty_payload_yields_no_data_quality()
    {
        using var doc = JsonDocument.Parse("""{"values":{}}""");
        var snap = WeatherObservationSnapshotMapper.FromHourlyPayload(
            Guid.NewGuid(), Guid.NewGuid(), "approved", null, null, doc.RootElement);
        Assert.Equal("no_data", snap.DataQuality);
        Assert.Empty(snap.FieldProvenance);
    }

    [Fact]
    public void Daily_merge_keeps_hourly_and_adds_daily_only_fields()
    {
        using var hourly = JsonDocument.Parse("""{"values":{"dryTemp":"+10.0","windSpeed":"05"}}""");
        using var daily = JsonDocument.Parse("""{"values":{"minTemp":"-01.0","maxTemp":"+12.0","precipitation":"001.0","maxGustSpeed":"15"}}""");
        var baseSnap = WeatherObservationSnapshotMapper.FromHourlyPayload(
            Guid.NewGuid(), Guid.NewGuid(), "approved", null, null, hourly.RootElement);
        var merged = WeatherObservationSnapshotMapper.MergeDailyExtras(baseSnap.Elements, daily.RootElement);
        Assert.Equal("+10.0", merged.DryTemp);
        Assert.Equal("05", merged.WindSpeed);
        Assert.Equal("-01.0", merged.MinTemp);
        Assert.Equal("+12.0", merged.MaxTemp);
        Assert.Equal("001.0", merged.PrecipitationDaily);
        Assert.Equal("15", merged.MaxGustSpeed);
        Assert.Null(merged.PrecipitationAmount);
    }
}
