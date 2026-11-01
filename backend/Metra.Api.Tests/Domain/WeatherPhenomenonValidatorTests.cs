using Metra.Api.Domain.Observations;
using Xunit;

namespace Metra.Api.Tests;

public sealed class WeatherPhenomenonValidatorTests
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Accepts_active_phenomenon_without_end_time(string? endTime)
    {
        var request = new WeatherPhenomenonRequest(
            "مطر خفيف",
            "2026-11-01",
            "06:15:00",
            endTime,
            "ملاحظات اختيارية");

        var issues = WeatherPhenomenonValidator.Validate(request);

        Assert.Empty(issues);
    }

    [Fact]
    public void Accepts_valid_ended_phenomenon()
    {
        var request = new WeatherPhenomenonRequest(
            "عاصفة رعدية",
            "2026-11-01",
            "06:15:00",
            "07:45:30",
            null);

        var issues = WeatherPhenomenonValidator.Validate(request);

        Assert.Empty(issues);
    }

    [Fact]
    public void Rejects_missing_phenomenon_type()
    {
        var request = new WeatherPhenomenonRequest(" ", "2026-11-01", "06:15:00", null, null);
        var issues = WeatherPhenomenonValidator.Validate(request);
        Assert.Contains(issues, issue => issue.Field == "phenomenon_type");
    }

    [Theory]
    [InlineData("01/11/2026")]
    [InlineData("2026-02-30")]
    [InlineData("")]
    public void Rejects_invalid_phenomenon_date(string date)
    {
        var request = new WeatherPhenomenonRequest("مطر", date, "06:15:00", null, null);
        var issues = WeatherPhenomenonValidator.Validate(request);
        Assert.Contains(issues, issue => issue.Field == "phenomenon_date");
    }

    [Theory]
    [InlineData("6:15:00")]
    [InlineData("25:00:00")]
    [InlineData("06:15")]
    public void Rejects_invalid_start_time(string time)
    {
        var request = new WeatherPhenomenonRequest("مطر", "2026-11-01", time, null, null);
        var issues = WeatherPhenomenonValidator.Validate(request);
        Assert.Contains(issues, issue => issue.Field == "start_time");
    }

    [Fact]
    public void Rejects_invalid_end_time()
    {
        var request = new WeatherPhenomenonRequest("مطر", "2026-11-01", "06:15:00", "25:61:00", null);
        var issues = WeatherPhenomenonValidator.Validate(request);
        Assert.Contains(issues, issue => issue.Field == "end_time");
    }

    [Fact]
    public void Rejects_null_request()
    {
        var issues = WeatherPhenomenonValidator.Validate(null);
        Assert.Contains(issues, issue => issue.Field == "request");
    }
}
