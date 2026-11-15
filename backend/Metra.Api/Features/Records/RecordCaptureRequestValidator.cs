using System.Text.Json;

namespace Metra.Api.Features.Records;

/// <summary>
/// Validates recorder capture metadata only. Station, instrument and actor
/// authorization must be resolved by an application service from trusted data.
/// </summary>
public sealed record RecordCaptureRequest(
    Guid StationId,
    Guid InstrumentId,
    string RecorderKind,
    DateTimeOffset CaptureStart,
    DateTimeOffset CaptureEnd,
    string PaperTimeZoneId,
    string ChartType,
    JsonElement? ChartScale);

public sealed record RecordCaptureValidationResult(bool IsValid, string? ErrorCode)
{
    public static RecordCaptureValidationResult Valid() => new(true, null);
    public static RecordCaptureValidationResult Invalid(string code) => new(false, code);
}

public static class RecordCaptureRequestValidator
{
    private static readonly HashSet<string> RecorderKinds = new(StringComparer.Ordinal)
    {
        "thermograph", "hygrograph", "barograph", "pluviograph"
    };

    public static RecordCaptureValidationResult Validate(RecordCaptureRequest? request)
    {
        if (request is null)
            return RecordCaptureValidationResult.Invalid("capture_request_required");
        if (request.StationId == Guid.Empty)
            return RecordCaptureValidationResult.Invalid("station_id_required");
        if (request.InstrumentId == Guid.Empty)
            return RecordCaptureValidationResult.Invalid("instrument_id_required");
        if (!RecorderKinds.Contains(request.RecorderKind))
            return RecordCaptureValidationResult.Invalid("unsupported_recorder_kind");
        if (request.CaptureEnd <= request.CaptureStart)
            return RecordCaptureValidationResult.Invalid("capture_interval_invalid");
        if (string.IsNullOrWhiteSpace(request.PaperTimeZoneId) ||
            request.PaperTimeZoneId.Length > 100 ||
            request.PaperTimeZoneId.Any(char.IsControl))
            return RecordCaptureValidationResult.Invalid("paper_timezone_invalid");
        if (string.IsNullOrWhiteSpace(request.ChartType) ||
            request.ChartType.Length > 80 ||
            request.ChartType.Any(char.IsControl))
            return RecordCaptureValidationResult.Invalid("chart_type_invalid");
        if (request.ChartScale is { } scale && scale.ValueKind != JsonValueKind.Object)
            return RecordCaptureValidationResult.Invalid("chart_scale_must_be_object");

        return RecordCaptureValidationResult.Valid();
    }
}
