using System.Globalization;
using System.Text.RegularExpressions;

namespace Metra.Api.Domain.Observations;

/// <summary>
/// Server-side validation for the legacy daily observation field codes.
/// Rules are transcribed from the original daily_validation.js; they are
/// intentionally isolated here so conflicts can be reconciled before reuse.
/// </summary>
public static class DailyObservationValidator
{
    private static readonly IReadOnlyDictionary<string, FieldRule> Rules =
        new Dictionary<string, FieldRule>(StringComparer.Ordinal)
        {
            ["minTemp"] = new(@"^-?\d{2}\.\d$", -20m, 50m, "درجة الحرارة الصغرى"),
            ["maxTemp"] = new(@"^-?\d{2}\.\d$", -20m, 50m, "درجة الحرارة العظمى"),
            ["precipitation"] = new(@"^\d{3}\.\d$", 0m, 999.9m, "الهطول"),
            ["snowThickness"] = new(@"^\d{3}$", 0m, 999m, "سماكة الثلج"),
            ["evaporation"] = new(@"^\d{2}\.\d$", 0m, 99.9m, "التبخر"),
            ["sunshineDuration"] = new(@"^\d{2}\.\d$", 0m, 24m, "مدة سطوع الشمس"),
            ["sunshinePercentage"] = new(@"^\d{3}$", 0m, 100m, "نسبة سطوع الشمس"),
            ["maxGustSpeed"] = new(@"^\d{2}$", 0m, 36m, "سرعة هبات الرياح"),
            ["maxGustDirection"] = new(@"^\d{2}$", 0m, 36m, "اتجاه هبات الرياح"),
            ["maxGustTime"] = new(@"^\d{2}\.\d$", 0m, 23.9m, "وقت هبة الرياح العظمى"),
            ["maxHumidityTime"] = new(@"^\d{2}\.\d$", 0m, 23.9m, "وقت الرطوبة العظمى"),
            ["minHumidityTime"] = new(@"^\d{2}\.\d$", 0m, 23.9m, "وقت الرطوبة الصغرى"),
            ["maxHumidity"] = new(@"^\d{3}$", 0m, 100m, "الرطوبة العظمى"),
            ["minHumidity"] = new(@"^\d{2}$", 0m, 99m, "الرطوبة الصغرى")
        };

    /// <param name="values">Field code to submitted text value.</param>
    /// <param name="requiredFields">Field codes required by the selected report type.</param>
    public static IReadOnlyList<ValidationIssue> Validate(
        IReadOnlyDictionary<string, string?> values,
        IReadOnlySet<string>? requiredFields = null)
    {
        ArgumentNullException.ThrowIfNull(values);
        var issues = new List<ValidationIssue>();

        foreach (var (field, value) in values)
        {
            var normalized = value?.Trim() ?? string.Empty;
            var required = requiredFields?.Contains(field) == true;

            if (normalized.Length == 0)
            {
                if (required)
                    issues.Add(new(field, $"حقل {GetLabel(field)} مطلوب."));
                continue;
            }

            // The original daily form explicitly treats # as a valid missing-value marker.
            if (normalized == "#")
                continue;

            if (field == "precipitationTrace")
            {
                if (!Regex.IsMatch(normalized, "^[Tt]$", RegexOptions.CultureInvariant))
                    issues.Add(new(field, "يجب إدخال حرف T فقط أو ترك الحقل فارغاً."));
                continue;
            }

            if (!Rules.TryGetValue(field, out var rule))
                continue;

            if (!Regex.IsMatch(normalized, rule.Pattern, RegexOptions.CultureInvariant) ||
                !decimal.TryParse(normalized, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var number) ||
                number < rule.Minimum || number > rule.Maximum)
            {
                issues.Add(new(field, $"قيمة {rule.Label} غير صالحة؛ التنسيق أو المجال المقبول غير مطابق."));
            }
        }

        if (requiredFields is not null)
        {
            foreach (var field in requiredFields)
            {
                if (!values.ContainsKey(field))
                    issues.Add(new(field, $"حقل {GetLabel(field)} مطلوب."));
            }
        }

        var maximumHumidity = GetValue(values, "maxHumidity");
        var minimumHumidity = GetValue(values, "minHumidity");
        if (maximumHumidity is not null && minimumHumidity is not null &&
            maximumHumidity != "#" && minimumHumidity != "#" &&
            decimal.TryParse(maximumHumidity, NumberStyles.None, CultureInfo.InvariantCulture, out var maximumHumidityValue) &&
            decimal.TryParse(minimumHumidity, NumberStyles.None, CultureInfo.InvariantCulture, out var minimumHumidityValue) &&
            minimumHumidityValue > maximumHumidityValue)
        {
            issues.Add(new("minHumidity", "الرطوبة الصغرى لا يمكن أن تتجاوز الرطوبة العظمى."));
        }

        var min = GetValue(values, "minTemp");
        var max = GetValue(values, "maxTemp");
        if (min is not null && max is not null && min != "#" && max != "#" &&
            decimal.TryParse(min, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var minValue) &&
            decimal.TryParse(max, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var maxValue) &&
            maxValue < minValue)
        {
            issues.Add(new("maxTemp", "درجة الحرارة العظمى يجب أن تكون أكبر من أو تساوي درجة الحرارة الصغرى."));
        }

        return issues;
    }

    private static string? GetValue(IReadOnlyDictionary<string, string?> values, string key)
        => values.TryGetValue(key, out var value) ? value?.Trim() : null;

    private static string GetLabel(string field)
        => Rules.TryGetValue(field, out var rule) ? rule.Label : field;

    private sealed record FieldRule(string Pattern, decimal Minimum, decimal Maximum, string Label);
}

public sealed record ValidationIssue(string Field, string Message);