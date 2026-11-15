using System.Text.Json;
using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecordCaptureRequestValidatorTests
{
    private static RecordCaptureRequest ValidRequest(
        string kind = "thermograph",
        DateTimeOffset? start = null,
        DateTimeOffset? end = null,
        string timezone = "Asia/Damascus",
        string chartType = "weekly",
        JsonElement? chartScale = null) =>
        new(Guid.NewGuid(), Guid.NewGuid(), kind,
            start ?? DateTimeOffset.Parse("2026-01-01T00:00:00Z"),
            end ?? DateTimeOffset.Parse("2026-01-08T00:00:00Z"),
            timezone, chartType, chartScale);

    [Theory]
    [InlineData("thermograph")]
    [InlineData("hygrograph")]
    [InlineData("barograph")]
    [InlineData("pluviograph")]
    public void Accepts_all_supported_recorder_kinds(string kind) =>
        Assert.True(RecordCaptureRequestValidator.Validate(ValidRequest(kind)).IsValid);

    [Theory]
    [InlineData("Thermograph")]
    [InlineData("unknown")]
    [InlineData("")]
    public void Rejects_unknown_or_noncanonical_recorder_kinds(string kind) =>
        Assert.Equal("unsupported_recorder_kind",
            RecordCaptureRequestValidator.Validate(ValidRequest(kind)).ErrorCode);

    [Fact]
    public void Rejects_empty_station_or_instrument_identifiers()
    {
        var request = ValidRequest() with { StationId = Guid.Empty };
        Assert.Equal("station_id_required", RecordCaptureRequestValidator.Validate(request).ErrorCode);
        request = ValidRequest() with { InstrumentId = Guid.Empty };
        Assert.Equal("instrument_id_required", RecordCaptureRequestValidator.Validate(request).ErrorCode);
    }

    [Theory]
    [InlineData("2026-01-02T00:00:00Z", "2026-01-01T00:00:00Z")]
    [InlineData("2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z")]
    public void Rejects_nonpositive_capture_intervals(string start, string end)
    {
        var request = ValidRequest(start: DateTimeOffset.Parse(start), end: DateTimeOffset.Parse(end));
        Assert.Equal("capture_interval_invalid", RecordCaptureRequestValidator.Validate(request).ErrorCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("invalid\\u0001zone")]
    public void Rejects_missing_or_control_character_paper_timezone(string timezone) =>
        Assert.Equal("paper_timezone_invalid",
            RecordCaptureRequestValidator.Validate(ValidRequest(timezone: timezone)).ErrorCode);

    [Fact]
    public void Rejects_paper_timezone_longer_than_policy_limit() =>
        Assert.Equal("paper_timezone_invalid",
            RecordCaptureRequestValidator.Validate(ValidRequest(timezone: new string('x', 101))).ErrorCode);

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("weekly\\u0001chart")]
    public void Rejects_missing_or_control_character_chart_type(string chartType) =>
        Assert.Equal("chart_type_invalid",
            RecordCaptureRequestValidator.Validate(ValidRequest(chartType: chartType)).ErrorCode);

    [Fact]
    public void Rejects_chart_type_longer_than_policy_limit() =>
        Assert.Equal("chart_type_invalid",
            RecordCaptureRequestValidator.Validate(ValidRequest(chartType: new string('x', 81))).ErrorCode);

    [Fact]
    public void Accepts_object_chart_scale_and_rejects_non_object_scale()
    {
        using var objectDocument = JsonDocument.Parse("{\"majorInterval\": 10}");
        using var arrayDocument = JsonDocument.Parse("[10, 20]");
        Assert.True(RecordCaptureRequestValidator.Validate(
            ValidRequest(chartScale: objectDocument.RootElement)).IsValid);
        Assert.Equal("chart_scale_must_be_object",
            RecordCaptureRequestValidator.Validate(
                ValidRequest(chartScale: arrayDocument.RootElement)).ErrorCode);
    }

    [Fact]
    public void Rejects_null_request() =>
        Assert.Equal("capture_request_required", RecordCaptureRequestValidator.Validate(null).ErrorCode);
}
