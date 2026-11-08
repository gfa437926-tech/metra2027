using System.Text.Json;
using Metra.Api.Domain.Observations;

namespace Metra.Api.Features.Observations;

/// <summary>
/// Version 1 field contract shared by validation and submission boundaries.
/// Values remain strings so legacy meteorological codes and fixed-width formats are preserved.
/// </summary>
public static class ObservationFieldContract
{
    public const string Version = "1.0";

    private static readonly IReadOnlyDictionary<string, IReadOnlySet<string>> DailyRequired =
        new Dictionary<string, IReadOnlySet<string>>(StringComparer.Ordinal)
        {
            ["24h"] = new HashSet<string>(StringComparer.Ordinal)
            {
                "minTemp", "maxTemp", "precipitation", "snowThickness",
                "evaporation", "sunshineDuration", "sunshinePercentage",
                "maxGustSpeed", "maxGustDirection", "maxGustTime",
                "maxHumidity", "maxHumidityTime", "minHumidity", "minHumidityTime"
            },
            ["06utc"] = new HashSet<string>(StringComparer.Ordinal)
            {
                "minTemp", "maxTemp", "precipitation", "snowThickness"
            },
            ["18utc"] = new HashSet<string>(StringComparer.Ordinal)
            {
                "minTemp", "maxTemp", "precipitation", "snowThickness"
            }
        };

    public static IReadOnlySet<string> GetDailyRequiredFields(string? reportType) =>
        reportType is not null && DailyRequired.TryGetValue(reportType, out var fields)
            ? fields
            : new HashSet<string>(StringComparer.Ordinal);

    public static bool IsDailyReportType(string? reportType) =>
        reportType is not null && DailyRequired.ContainsKey(reportType);

    /// <summary>Validates the canonical submission payload: { reportType?, values, responsibilityAgreement? }.</summary>
    public static IReadOnlyList<ValidationIssue> ValidateSubmission(string observationType, JsonElement payload)
    {
        if (payload.ValueKind != JsonValueKind.Object ||
            !payload.TryGetProperty("values", out var valuesElement) ||
            valuesElement.ValueKind != JsonValueKind.Object)
        {
            return [new("values", "يجب إرسال كائن values ضمن حمولة النشرة.")];
        }

        var values = new Dictionary<string, string?>(StringComparer.Ordinal);
        foreach (var property in valuesElement.EnumerateObject())
        {
            if (property.Value.ValueKind == JsonValueKind.String)
                values[property.Name] = property.Value.GetString();
            else if (property.Value.ValueKind == JsonValueKind.Null)
                values[property.Name] = null;
            else
                return [new(property.Name, "يجب إرسال قيم الحقول كسلاسل نصية.")];
        }

        if (observationType == "hourly")
            return HourlyObservationValidator.Validate(values);

        if (observationType == "daily")
        {
            var reportType = payload.TryGetProperty("reportType", out var typeElement) &&
                typeElement.ValueKind == JsonValueKind.String
                    ? typeElement.GetString()
                    : null;
            if (!IsDailyReportType(reportType))
                return [new("reportType", "نوع النشرة اليومية يجب أن يكون 24h أو 06utc أو 18utc.")];

            if (!payload.TryGetProperty("responsibilityAgreement", out var agreement) ||
                agreement.ValueKind != JsonValueKind.True)
                return [new("responsibilityAgreement", "يجب تأكيد إقرار المسؤولية قبل إرسال النشرة اليومية.")];

            return DailyObservationValidator.Validate(values, GetDailyRequiredFields(reportType));
        }

        return [];
    }
}
