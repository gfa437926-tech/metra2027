using System.Text.Json;

namespace Metra.Api.Domain.Forecasting;

/// <summary>
/// Read model for forecasting centre snapshots. Maps only known payload keys;
/// missing values remain null (never coerced to zero).
/// </summary>
public sealed class WeatherObservationSnapshot
{
    public const string ContractVersion = "weather-observation-snapshot/1.0";

    public required string ContractVersionValue { get; init; }
    public Guid StationId { get; init; }
    public string? StationCode { get; init; }
    public string? WmoStationId { get; init; }
    public string? StationNameAr { get; init; }
    public Guid? SourceObservationId { get; init; }
    public string? SourceObservationType { get; init; }
    public string? ApprovalStatus { get; init; }
    public DateTimeOffset? ObservedAtUtc { get; init; }
    public DateTimeOffset? ReceivedAtUtc { get; init; }
    public DateTimeOffset RetrievedAtUtc { get; init; }
    public string DataQuality { get; init; } = "no_data";
    public string Freshness { get; init; } = "no_data";
    public string SourceSystem { get; init; } = "metra_observations";
    public WeatherSnapshotElements Elements { get; init; } = new();
    public IReadOnlyDictionary<string, string> FieldProvenance { get; init; } =
        new Dictionary<string, string>(StringComparer.Ordinal);
}

public sealed class WeatherSnapshotElements
{
    public string? DryTemp { get; init; }
    public string? WetTemp { get; init; }
    public string? DewPoint { get; init; }
    public string? MinTemp { get; init; }
    public string? MaxTemp { get; init; }
    public string? StationPressure { get; init; }
    public string? SeaLevelPressure { get; init; }
    public string? RelativeHumidity { get; init; }
    public string? WindSpeed { get; init; }
    public string? WindDirection { get; init; }
    public string? MaxGustSpeed { get; init; }
    public string? MaxGustDirection { get; init; }
    public string? PrecipitationAmount { get; init; }
    public string? PrecipitationDaily { get; init; }
    public string? PrecipitationTrace { get; init; }
    public string? Visibility { get; init; }
    public string? TotalCloudCover { get; init; }
}

public static class WeatherObservationSnapshotMapper
{
    public static WeatherObservationSnapshot FromHourlyPayload(
        Guid stationId,
        Guid observationId,
        string? approvalStatus,
        DateTimeOffset? observedAtUtc,
        DateTimeOffset? receivedAtUtc,
        JsonElement payload,
        string? stationCode = null,
        string? stationNameAr = null)
    {
        var values = ExtractValuesObject(payload);
        var elements = new WeatherSnapshotElements
        {
            DryTemp = ReadString(values, "dryTemp"),
            WetTemp = ReadString(values, "wetTemp"),
            DewPoint = ReadString(values, "dewPoint"),
            StationPressure = ReadString(values, "stationPressure"),
            SeaLevelPressure = ReadString(values, "seaLevelPressure"),
            RelativeHumidity = ReadString(values, "relativeHumidity"),
            WindSpeed = ReadString(values, "windSpeed"),
            WindDirection = ReadString(values, "windDirection"),
            PrecipitationAmount = ReadString(values, "precipitationAmount"),
            Visibility = ReadString(values, "visibility"),
            TotalCloudCover = ReadString(values, "totalCloudCover")
        };

        var provenance = new Dictionary<string, string>(StringComparer.Ordinal);
        void Mark(string name, string? value)
        {
            if (value is not null)
                provenance[name] = "hourly.values";
        }
        Mark(nameof(elements.DryTemp), elements.DryTemp);
        Mark(nameof(elements.WetTemp), elements.WetTemp);
        Mark(nameof(elements.DewPoint), elements.DewPoint);
        Mark(nameof(elements.StationPressure), elements.StationPressure);
        Mark(nameof(elements.SeaLevelPressure), elements.SeaLevelPressure);
        Mark(nameof(elements.RelativeHumidity), elements.RelativeHumidity);
        Mark(nameof(elements.WindSpeed), elements.WindSpeed);
        Mark(nameof(elements.WindDirection), elements.WindDirection);
        Mark(nameof(elements.PrecipitationAmount), elements.PrecipitationAmount);
        Mark(nameof(elements.Visibility), elements.Visibility);
        Mark(nameof(elements.TotalCloudCover), elements.TotalCloudCover);

        var hasAny = provenance.Count > 0;
        return new WeatherObservationSnapshot
        {
            ContractVersionValue = WeatherObservationSnapshot.ContractVersion,
            StationId = stationId,
            StationCode = stationCode,
            StationNameAr = stationNameAr,
            SourceObservationId = observationId,
            SourceObservationType = "hourly",
            ApprovalStatus = approvalStatus,
            ObservedAtUtc = observedAtUtc,
            ReceivedAtUtc = receivedAtUtc,
            RetrievedAtUtc = DateTimeOffset.UtcNow,
            DataQuality = hasAny ? "partial_or_complete" : "no_data",
            Freshness = "unknown_policy",
            Elements = elements,
            FieldProvenance = provenance
        };
    }

    public static WeatherSnapshotElements MergeDailyExtras(
        WeatherSnapshotElements hourly,
        JsonElement dailyPayload)
    {
        var values = ExtractValuesObject(dailyPayload);
        return new WeatherSnapshotElements
        {
            DryTemp = hourly.DryTemp,
            WetTemp = hourly.WetTemp,
            DewPoint = hourly.DewPoint,
            StationPressure = hourly.StationPressure,
            SeaLevelPressure = hourly.SeaLevelPressure,
            RelativeHumidity = hourly.RelativeHumidity,
            WindSpeed = hourly.WindSpeed,
            WindDirection = hourly.WindDirection,
            PrecipitationAmount = hourly.PrecipitationAmount,
            Visibility = hourly.Visibility,
            TotalCloudCover = hourly.TotalCloudCover,
            MinTemp = ReadString(values, "minTemp"),
            MaxTemp = ReadString(values, "maxTemp"),
            MaxGustSpeed = ReadString(values, "maxGustSpeed"),
            MaxGustDirection = ReadString(values, "maxGustDirection"),
            PrecipitationDaily = ReadString(values, "precipitation"),
            PrecipitationTrace = ReadString(values, "precipitationTrace")
        };
    }

    private static JsonElement ExtractValuesObject(JsonElement payload)
    {
        if (payload.ValueKind == JsonValueKind.Object &&
            payload.TryGetProperty("values", out var values) &&
            values.ValueKind == JsonValueKind.Object)
            return values;
        return default;
    }

    private static string? ReadString(JsonElement values, string name)
    {
        if (values.ValueKind != JsonValueKind.Object)
            return null;
        if (!values.TryGetProperty(name, out var el))
            return null;
        if (el.ValueKind != JsonValueKind.String)
            return null;
        var text = el.GetString();
        return string.IsNullOrWhiteSpace(text) ? null : text.Trim();
    }
}
