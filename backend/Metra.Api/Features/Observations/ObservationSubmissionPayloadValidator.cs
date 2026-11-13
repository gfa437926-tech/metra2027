using System.Text.Json;
using Metra.Api.Domain.Observations;

namespace Metra.Api.Features.Observations;

/// <summary>
/// Enforces the source-derived scientific field contracts before persistence.
/// The database RPC remains responsible for actor/station authorization and workflow state.
/// </summary>
public static class ObservationSubmissionPayloadValidator
{
    private static readonly HashSet<string> Daily24HourRequiredFields = new(StringComparer.Ordinal)
    {
        "minTemp", "maxTemp", "precipitation", "snowThickness",
        "evaporation", "sunshineDuration", "sunshinePercentage",
        "maxGustSpeed", "maxGustDirection", "maxGustTime",
        "maxHumidity", "maxHumidityTime", "minHumidity", "minHumidityTime"
    };

    private static readonly HashSet<string> ServerOwnedFields = new(StringComparer.OrdinalIgnoreCase)
    {
        "user_id", "station_id", "created_by", "status", "submitted_at",
        "approved_by", "approval_status", "observer_id", "observer_name",
        "station_name", "user_role", "authority_id"
    };

    public static IReadOnlyList<ValidationIssue> Validate(ObservationSubmissionRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (request.Payload is not { ValueKind: JsonValueKind.Object } payload)
            return [new("payload", "يجب أن تكون بيانات الرصد كائناً JSON.")];

        var issues = new List<ValidationIssue>();
        foreach (var property in payload.EnumerateObject())
        {
            if (ServerOwnedFields.Contains(property.Name))
                issues.Add(new(property.Name, "هذا الحقل يحدده الخادم ولا يجوز إرساله من العميل."));
        }
        if (issues.Count > 0) return issues;

        if (request.ObservationType == "hourly")
            return HourlyObservationValidator.Validate(ToValues(payload));

        if (request.ObservationType == "daily")
        {
            var values = ToValues(payload);
            if (!values.TryGetValue("reportType", out var reportType) ||
                string.IsNullOrWhiteSpace(reportType))
                return [new("reportType", "نوع التقرير اليومي مطلوب لتحديد الحقول العلمية الإلزامية.")];

            if (reportType is "06utc" or "18utc")
                return [new("reportType", "عقد تقريري 06 و18 UTC غير معتمد: مصدر الإدخال يطلب الهطول والثلج، بينما محول التخزين القديم يستبعدهما. لا يمكن قبول الإرسال قبل حسم التعارض.")];

            if (reportType != "24h")
                return [new("reportType", "نوع التقرير يجب أن يكون 24h أو 06utc أو 18utc.")];

            return DailyObservationValidator.Validate(values, Daily24HourRequiredFields);
        }

        if (request.ObservationType == "phenomenon")
        {
            var phenomenon = new WeatherPhenomenonRequest(
                GetString(payload, "phenomenonType"),
                GetString(payload, "phenomenonDate"),
                GetString(payload, "startTime"),
                GetString(payload, "endTime"),
                GetString(payload, "generalNotes"));
            return WeatherPhenomenonValidator.Validate(phenomenon);
        }

        return [new("observationType", "نوع الرصد غير مدعوم.")];
    }

    private static Dictionary<string, string?> ToValues(JsonElement payload)
    {
        var values = new Dictionary<string, string?>(StringComparer.Ordinal);
        foreach (var property in payload.EnumerateObject())
        {
            values[property.Name] = property.Value.ValueKind switch
            {
                JsonValueKind.Null or JsonValueKind.Undefined => null,
                JsonValueKind.String => property.Value.GetString(),
                JsonValueKind.Number => property.Value.GetRawText(),
                JsonValueKind.True => "true",
                JsonValueKind.False => "false",
                _ => property.Value.GetRawText()
            };
        }
        return values;
    }

    private static string? GetString(JsonElement payload, string name) =>
        payload.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;
}
