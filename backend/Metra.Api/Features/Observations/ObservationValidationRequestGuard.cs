namespace Metra.Api.Features.Observations;

/// <summary>
/// Guards untrusted validation payloads before domain validation.
/// Structural only: no database reads, no station/user disclosure.
/// Authentication is enforced by the API fallback JWT policy (not anonymous).
/// Bounds limit abuse (large/repeated payloads) without inventing rate-limit infra.
/// </summary>
public static class ObservationValidationRequestGuard
{
    public const int MaximumFields = 100;
    /// <summary>
    /// Aligns with Flutter catalogue default maxLength (256) so observer notes
    /// can be validated end-to-end. Upper bound remains field-count × this value.
    /// </summary>
    public const int MaximumValueLength = 256;
    public const int MaximumFieldNameLength = 64;

    public static string? GetError(Dictionary<string, string?>? values)
    {
        if (values is null)
            return "يجب إرسال كائن values.";

        if (values.Count == 0)
            return "يجب إرسال حقل واحد على الأقل للتحقق.";

        if (values.Count > MaximumFields)
            return $"عدد الحقول يتجاوز الحد المسموح ({MaximumFields}).";

        foreach (var (field, value) in values)
        {
            if (string.IsNullOrWhiteSpace(field) || field.Length > MaximumFieldNameLength)
                return "اسم أحد الحقول فارغ أو أطول من الحد المسموح.";

            if (value is { Length: > MaximumValueLength })
                return $"قيمة الحقل {field} أطول من الحد المسموح.";
        }

        return null;
    }
}
