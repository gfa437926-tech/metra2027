using System.Globalization;

namespace Metra.Api.Domain.Observations;

/// <summary>
/// Structural validation for the weather-phenomenon recording contract.
/// This does not persist records or establish the caller's identity/station.
/// </summary>
public static class WeatherPhenomenonValidator
{
    public static IReadOnlyList<ValidationIssue> Validate(WeatherPhenomenonRequest? request)
    {
        var issues = new List<ValidationIssue>();
        if (request is null)
        {
            issues.Add(new("request", "بيانات الطلب مطلوبة."));
            return issues;
        }

        if (string.IsNullOrWhiteSpace(request.PhenomenonType))
            issues.Add(new("phenomenon_type", "حقل نوع الظاهرة الجوية مطلوب."));
        else if (request.PhenomenonType.Length > 64)
            issues.Add(new("phenomenon_type", "نوع الظاهرة الجوية يتجاوز الحد الأقصى المسموح (64 حرفاً)."));

        if (request.GeneralNotes is { Length: > 2000 })
            issues.Add(new("general_notes", "ملاحظات الظاهرة تتجاوز الحد الأقصى المسموح (2000 حرف)."));

        if (!DateOnly.TryParseExact(
                request.PhenomenonDate,
                "yyyy-MM-dd",
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out _))
            issues.Add(new("phenomenon_date", "التاريخ يجب أن يكون بالتنسيق yyyy-MM-dd."));

        if (!TimeOnly.TryParseExact(
                request.StartTime,
                "HH:mm:ss",
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out _))
            issues.Add(new("start_time", "وقت البدء يجب أن يكون بالتنسيق HH:mm:ss بتوقيت UTC."));

        // An omitted, null, empty or whitespace end time means the phenomenon is active.
        if (!string.IsNullOrWhiteSpace(request.EndTime))
        {
            if (!TimeOnly.TryParseExact(
                    request.EndTime,
                    "HH:mm:ss",
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.None,
                    out var endTime))
            {
                issues.Add(new("end_time", "وقت الانتهاء يجب أن يكون بالتنسيق HH:mm:ss بتوقيت UTC."));
            }
            else if (TimeOnly.TryParseExact(
                         request.StartTime,
                         "HH:mm:ss",
                         CultureInfo.InvariantCulture,
                         DateTimeStyles.None,
                         out var startTime) &&
                     endTime < startTime)
            {
                issues.Add(new("end_time", "وقت الانتهاء لا يجوز أن يسبق وقت البدء في اليوم نفسه."));
            }
        }

        return issues;
    }
}

/// <summary>
/// Client input only. User, station, role and workflow status are deliberately
/// excluded; those values must come from authenticated server-side context.
/// </summary>
public sealed record WeatherPhenomenonRequest(
    string? PhenomenonType,
    string? PhenomenonDate,
    string? StartTime,
    string? EndTime,
    string? GeneralNotes);
