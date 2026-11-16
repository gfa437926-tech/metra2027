using System.Globalization;
using System.Text.Json;
using Metra.Api.Domain.Observations;

namespace Metra.Api.Features.Observations;

/// <summary>
/// Runs the approved legacy daily/hourly domain validators on the actual
/// persistence payload. The Flutter client sends typed JSON values, while
/// the legacy validators consume the fixed-width meteorological code format.
/// </summary>
public static class ObservationSubmissionDomainValidator
{
    private static readonly IReadOnlySet<string> DailyRequired = new HashSet<string>(StringComparer.Ordinal)
    {
        "currentDate", "minTemp", "maxTemp", "precipitation", "snowThickness",
        "evaporation", "sunshineDuration", "sunshinePercentage", "maxGustSpeed",
        "maxGustDirection", "maxGustTime", "maxHumidity", "maxHumidityTime",
        "minHumidity", "minHumidityTime", "responsibilityAgreement"
    };

    private static readonly IReadOnlySet<string> HourlyRequired = new HashSet<string>(StringComparer.Ordinal)
    {
        "utcTime", "dryTemp", "wetTemp", "stationPressure", "seaLevelPressure",
        "relativeHumidity", "dewPoint", "windDirection", "windSpeed", "visibility",
        "totalCloudCover", "cover12", "cover123", "responsibilityAgreement"
    };

    public static IReadOnlyList<ValidationIssue> Validate(ObservationSubmissionRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (request.Payload is not JsonElement payload || payload.ValueKind != JsonValueKind.Object)
            return [new("payload", "يجب أن تكون حمولة الرصد كائناً مسطحاً.")];

        if (request.ObservationType == "phenomenon")
            return [new("observationType", "التحقق الخادمي لهذا النوع من الرصد لم يُربط بعد؛ أُوقف الحفظ لمنع تجاوز التحقق.")];

        if (request.ObservationType is not ("daily" or "hourly"))
            return [new("observationType", "نوع الرصد غير مدعوم.")];

        var values = new Dictionary<string, string?>(StringComparer.Ordinal);
        foreach (var property in payload.EnumerateObject())
        {
            var value = property.Value.ValueKind switch
            {
                JsonValueKind.Null => null,
                JsonValueKind.String => property.Value.GetString(),
                JsonValueKind.Number => property.Value.GetRawText(),
                JsonValueKind.True => "true",
                JsonValueKind.False => "false",
                _ => null
            };

            if (property.Value.ValueKind is JsonValueKind.Array or JsonValueKind.Object)
                return [new(property.Name, "يجب أن تكون قيمة الحقل نصاً أو رقماً أو قيمة منطقية.")];

            values[property.Name] = FormatLegacyValue(request.ObservationType, property.Name, value);
        }

        if (request.ObservationType == "daily")
        {
            var issues = DailyObservationValidator.Validate(values, DailyRequired).ToList();
            RequireAffirmation(values, issues);
            return issues;
        }

        var hourlyIssues = HourlyObservationValidator.Validate(values).ToList();
        foreach (var field in HourlyRequired)
        {
            if (!values.ContainsKey(field) || string.IsNullOrWhiteSpace(values[field]))
                hourlyIssues.Add(new(field, "هذا الحقل مطلوب لإرسال الرصد الساعي."));
        }
        RequireAffirmation(values, hourlyIssues);
        return hourlyIssues;
    }

    private static void RequireAffirmation(
        IReadOnlyDictionary<string, string?> values,
        List<ValidationIssue> issues)
    {
        if (!values.TryGetValue("responsibilityAgreement", out var value) ||
            !string.Equals(value, "true", StringComparison.OrdinalIgnoreCase))
            issues.Add(new("responsibilityAgreement", "يجب تأكيد الإقرار بصحة بيانات الرصد."));
    }

    private static string? FormatLegacyValue(string type, string field, string? raw)
    {
        if (raw is null) return null;
        var value = raw.Trim();
        if (value.Length == 0 || value == "#") return value;

        var integerWidth = type == "daily"
            ? field switch
            {
                "snowThickness" or "sunshinePercentage" or "maxHumidity" => 3,
                "maxGustSpeed" or "maxGustDirection" or "minHumidity" => 2,
                _ => 0
            }
            : field switch
            {
                "relativeHumidity" or "visibility" => 3,
                "windDirection" or "avgWindDirection" or "windSpeed" or "avgWindSpeed" or "currentWeather" => 2,
                "pastWeather" or "totalCloudCover" or "cloud1Amount" or "cloud2Amount" or "cloud3Amount" or "cloud4Amount" or "cover12" or "cover123" or "pressureShape" => 1,
                _ => 0
            };

        if (integerWidth > 0 && decimal.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var integer))
            return integer.ToString(CultureInfo.InvariantCulture).PadLeft(integerWidth, '0');

        var decimalWidth = type == "daily"
            ? field switch
            {
                "minTemp" or "maxTemp" => 2,
                "precipitation" => 3,
                "evaporation" or "sunshineDuration" or "maxGustTime" or "maxHumidityTime" or "minHumidityTime" => 2,
                _ => 0
            }
            : field switch
            {
                "dryTemp" or "wetTemp" or "dewPoint" => 2,
                "stationPressure" or "seaLevelPressure" => 4,
                "vaporPressure" or "vaporPressureDiff" => 2,
                "pressureSlope" => 1,
                "precipitationAmount" => 3,
                _ => 0
            };

        if (decimalWidth == 0 ||
            !decimal.TryParse(value, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var number))
            return value;

        var negative = number < 0;
        var absolute = Math.Abs(number);
        var formatted = absolute.ToString(CultureInfo.InvariantCulture);
        var parts = formatted.Split('.');
        if (parts.Length > 2 || (parts.Length == 2 && parts[1].Length != 1))
            return value;

        var fraction = parts.Length == 2 ? parts[1] : "0";
        var sign = negative ? "-" :
            type == "hourly" && field is ("dryTemp" or "wetTemp" or "dewPoint") ? "+" : string.Empty;
        return sign + parts[0].PadLeft(decimalWidth, '0') + "." + fraction;
    }
}
