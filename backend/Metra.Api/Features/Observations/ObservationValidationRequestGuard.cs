namespace Metra.Api.Features.Observations;

/// <summary>Guards untrusted validation payloads before domain validation.</summary>
public static class ObservationValidationRequestGuard
{
    public const int MaximumFields = 100;
    public const int MaximumValueLength = 64;
    public const int MaximumFieldNameLength = 64;
    public const int MaximumAggregateValueLength = 4096;

    public static string? GetError(Dictionary<string, string?>? values)
    {
        if (values is null)
            return "يجب إرسال كائن values.";

        if (values.Count == 0)
            return "يجب إرسال حقل واحد على الأقل للتحقق.";

        if (values.Count > MaximumFields)
            return $"عدد الحقول يتجاوز الحد المسموح ({MaximumFields}).";

        var aggregateLength = 0;
        foreach (var (field, value) in values)
        {
            if (string.IsNullOrWhiteSpace(field) || field.Length > MaximumFieldNameLength ||
                field != field.Trim() ||
                field.Any(character => !char.IsAsciiLetterOrDigit(character) && character != '_'))
                return "اسم أحد الحقول فارغ أو يحتوي محارف غير مسموحة.";

            if (value is { Length: > MaximumValueLength })
                return $"قيمة الحقل {field} أطول من الحد المسموح.";

            if (value?.Any(char.IsControl) == true)
                return $"قيمة الحقل {field} تحتوي محارف تحكم غير مسموحة.";

            aggregateLength += value?.Length ?? 0;
            if (aggregateLength > MaximumAggregateValueLength)
                return $"إجمالي حجم بيانات الحقول يتجاوز الحد المسموح ({MaximumAggregateValueLength}).";
        }

        return null;
    }
}