namespace Metra.Api.Features.Observations;

/// <summary>
/// Contract for a future authenticated submission endpoint. Station identity
/// is deliberately absent: the API must resolve it from the validated METRA
/// principal and authoritative station assignments.
/// </summary>
public sealed record CreateHourlyObservationRequest(
    DateOnly ObservationDate,
    int UtcHour,
    Dictionary<string, string?>? Values);

/// <summary>
/// Canonical workflow states. A submitted observation remains pending until
/// an authorized station reviewer makes an explicit decision.
/// </summary>
public enum HourlyObservationStatus
{
    PendingReview = 0,
    Approved = 1,
    Rejected = 2
}

public sealed record HourlyObservationSubmissionResponse(
    string ObservationId,
    string StationId,
    DateOnly ObservationDate,
    int UtcHour,
    HourlyObservationStatus Status,
    DateTimeOffset SubmittedAt,
    string SubmittedBy);

public sealed record HourlyObservationReviewRequest(
    HourlyObservationReviewDecision Decision,
    string? Note);

public enum HourlyObservationReviewDecision
{
    Approve = 1,
    Reject = 2
}

public sealed record HourlyObservationReviewResponse(
    string ObservationId,
    HourlyObservationStatus Status,
    string ReviewedBy,
    DateTimeOffset ReviewedAt,
    string? Note);

/// <summary>
/// Input checks shared by endpoint handlers and tests. This does not replace
/// HourlyObservationValidator; it validates workflow metadata and payload size.
/// </summary>
public static class HourlyObservationContractValidator
{
    public const int MaximumReviewNoteLength = 1000;

    public static IReadOnlyList<string> ValidateSubmission(CreateHourlyObservationRequest? request)
    {
        var errors = new List<string>();
        if (request is null)
        {
            errors.Add("بيانات الإرسال مطلوبة.");
            return errors;
        }

        if (request.ObservationDate == default)
            errors.Add("تاريخ الرصد مطلوب.");

        if (request.UtcHour is < 0 or > 23)
            errors.Add("ساعة الرصد يجب أن تكون بين 00 و23 UTC.");

        var payloadError = ObservationValidationRequestGuard.GetError(request.Values);
        if (payloadError is not null)
            errors.Add(payloadError);

        if (request.Values is not null &&
            request.Values.TryGetValue("utcTime", out var payloadHour) &&
            !string.Equals(payloadHour, request.UtcHour.ToString("00", System.Globalization.CultureInfo.InvariantCulture), StringComparison.Ordinal))
            errors.Add("ساعة UTC في بيانات الرصد لا تطابق ساعة الإرسال.");

        return errors;
    }

    public static IReadOnlyList<string> ValidateReview(HourlyObservationReviewRequest? request)
    {
        var errors = new List<string>();
        if (request is null)
        {
            errors.Add("قرار المراجعة مطلوب.");
            return errors;
        }

        if (!Enum.IsDefined(request.Decision))
            errors.Add("قرار المراجعة غير معروف.");

        if (request.Note is { Length: > MaximumReviewNoteLength })
            errors.Add($"ملاحظة المراجعة يجب ألا تتجاوز {MaximumReviewNoteLength} محرف.");

        if (request.Note is not null && request.Note.Any(char.IsControl) &&
            request.Note.Any(character => character is not '\r' and not '\n' and not '\t'))
            errors.Add("ملاحظة المراجعة تحتوي محارف تحكم غير مسموحة.");

        if (request.Decision == HourlyObservationReviewDecision.Reject &&
            string.IsNullOrWhiteSpace(request.Note))
            errors.Add("يجب توضيح سبب رفض الرصد.");

        return errors;
    }
}
