using System.Globalization;
using System.Text.RegularExpressions;

namespace Metra.Api.Domain.Observations;

/// <summary>
/// Authoritative hourly-observation validation based on hourly_reports.html,
/// hourly-send.js and enhanced-validation.js. Conditional requirements are
/// derived from the selected UTC observation hour.
/// </summary>
public static class HourlyObservationValidator
{
    private static readonly HashSet<int> SynopticHours = [0, 3, 6, 9, 12, 15, 18, 21];
    private static readonly HashSet<int> PrecipitationHours = [0, 6, 12, 18];

    private static readonly IReadOnlyDictionary<string, FieldRule> Rules =
        new Dictionary<string, FieldRule>(StringComparer.Ordinal)
        {
            ["dryTemp"] = new(@"^[+-]\d{2}\.\d$", -20m, 50m, "الحرارة الجافة"),
            ["wetTemp"] = new(@"^[+-]\d{2}\.\d$", -20m, 50m, "الحرارة الرطبة"),
            ["dewPoint"] = new(@"^[+-]\d{2}\.\d$", -20m, 50m, "نقطة الندى"),
            ["stationPressure"] = new(@"^\d{4}\.\d$", 850m, 1050m, "الضغط الجوي بالمحطة"),
            ["seaLevelPressure"] = new(@"^\d{4}\.\d$", 0m, 1050m, "الضغط المصحح لمستوى سطح البحر"),
            ["relativeHumidity"] = new(@"^\d{3}$", 1m, 100m, "الرطوبة النسبية"),
            ["vaporPressure"] = new(@"^\d{2}\.\d$", 0m, 99m, "ضغط البخار"),
            ["vaporPressureDiff"] = new(@"^\d{2}\.\d$", 0m, 99m, "فرق ضغط البخار"),
            ["windDirection"] = new(@"^\d{2}$", 0m, 36m, "اتجاه الرياح"),
            ["avgWindDirection"] = new(@"^\d{2}$", 0m, 36m, "متوسط اتجاه الرياح"),
            ["windSpeed"] = new(@"^\d{2}$", 0m, 99m, "سرعة الرياح"),
            ["avgWindSpeed"] = new(@"^\d{2}$", 0m, 99m, "متوسط سرعة الرياح"),
            ["visibility"] = new(@"^\d{3}$", 0m, 200m, "مدى الرؤية"),
            ["currentWeather"] = new(@"^\d{2}$", 0m, 99m, "الطقس الحالي"),
            ["pastWeather"] = new(@"^\d$", 0m, 9m, "الطقس السابق"),
            ["totalCloudCover"] = new(@"^\d$", 0m, 8m, "التغطية الكلية للسحب"),
            ["cloud1Amount"] = new(@"^[0-8]$", 0m, 8m, "كمية السحب الأولى"),
            ["cloud2Amount"] = new(@"^[0-8]$", 0m, 8m, "كمية السحب الثانية"),
            ["cloud3Amount"] = new(@"^[0-8]$", 0m, 8m, "كمية السحب الثالثة"),
            ["cloud4Amount"] = new(@"^[0-8]$", 0m, 8m, "كمية السحب الرابعة"),
            ["cloud1Height"] = new(@"^\d{1,3}$", 0m, 999m, "ارتفاع السحب الأولى"),
            ["cloud2Height"] = new(@"^\d{1,3}$", 0m, 999m, "ارتفاع السحب الثانية"),
            ["cloud3Height"] = new(@"^\d{1,3}$", 0m, 999m, "ارتفاع السحب الثالثة"),
            ["cover12"] = new(@"^[0-8]$", 0m, 8m, "تغطية الطبقتين الأولى والثانية"),
            ["cover123"] = new(@"^[0-8]$", 0m, 8m, "تغطية الطبقات الثلاث"),
            ["pressureSlope"] = new(@"^\d{1,2}\.\d$", 0m, 99m, "ميل الضغط"),
            ["pressureShape"] = new(@"^[0-8]$", 0m, 8m, "شكل تغير الضغط"),
            ["precipitationAmount"] = new(@"^\d{3}\.\d$", 0m, 999.9m, "كمية الهطول")
        };

    private static readonly string[] AlwaysRequired =
    [
        "dryTemp", "wetTemp", "stationPressure", "seaLevelPressure",
        "windDirection", "windSpeed", "visibility", "totalCloudCover",
        "relativeHumidity", "dewPoint", "cover12", "cover123"
    ];

    public static IReadOnlyList<ValidationIssue> Validate(IReadOnlyDictionary<string, string?> values)
    {
        ArgumentNullException.ThrowIfNull(values);
        var issues = new List<ValidationIssue>();

        var utcText = GetValue(values, "utcTime");
        if (string.IsNullOrWhiteSpace(utcText))
        {
            issues.Add(new("utcTime", "ساعة الرصد بالتوقيت العالمي مطلوبة."));
            return issues;
        }

        if (!Regex.IsMatch(utcText, @"^\d{2}$", RegexOptions.CultureInvariant) ||
            !int.TryParse(utcText, NumberStyles.None, CultureInfo.InvariantCulture, out var hour) || hour is < 0 or > 23)
        {
            issues.Add(new("utcTime", "يجب اختيار ساعة صحيحة من 00 إلى 23 بالتوقيت العالمي."));
            return issues;
        }

        var required = new HashSet<string>(AlwaysRequired, StringComparer.Ordinal);
        if (PrecipitationHours.Contains(hour)) required.Add("precipitationAmount");
        if (SynopticHours.Contains(hour))
        {
            required.Add("pressureSlope");
            required.Add("pressureShape");
            required.Add("pastWeather");
        }

        foreach (var field in required)
        {
            var value = GetValue(values, field);
            if (string.IsNullOrWhiteSpace(value))
                issues.Add(new(field, $"حقل {GetLabel(field)} مطلوب في ساعة الرصد {hour:00} UTC."));
        }

        foreach (var (field, rawValue) in values)
        {
            if (!Rules.TryGetValue(field, out var rule)) continue;
            var value = rawValue?.Trim() ?? string.Empty;
            if (value.Length == 0 || value == "#") continue;
            if (!Regex.IsMatch(value, rule.Pattern, RegexOptions.CultureInvariant) ||
                !decimal.TryParse(value, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var number) ||
                number < rule.Minimum || number > rule.Maximum)
            {
                issues.Add(new(field, $"قيمة {rule.Label} غير صالحة؛ تحقق من التنسيق والمجال المسموح."));
            }
        }

        ValidateTemperatureRelationship(values, issues);
        return issues;
    }

    private static void ValidateTemperatureRelationship(IReadOnlyDictionary<string, string?> values, List<ValidationIssue> issues)
    {
        var dry = GetValue(values, "dryTemp");
        var wet = GetValue(values, "wetTemp");
        if (string.IsNullOrWhiteSpace(dry) || string.IsNullOrWhiteSpace(wet) || dry == "#" || wet == "#") return;
        if (decimal.TryParse(dry, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var dryValue) &&
            decimal.TryParse(wet, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var wetValue) &&
            dryValue < wetValue)
        {
            issues.Add(new("dryTemp", "يجب أن تكون درجة الحرارة الجافة أكبر من أو تساوي درجة الحرارة الرطبة."));
        }
    }

    private static string? GetValue(IReadOnlyDictionary<string, string?> values, string key)
        => values.TryGetValue(key, out var value) ? value?.Trim() : null;

    private static string GetLabel(string field)
        => Rules.TryGetValue(field, out var rule) ? rule.Label : field;

    private sealed record FieldRule(string Pattern, decimal Minimum, decimal Maximum, string Label);
}