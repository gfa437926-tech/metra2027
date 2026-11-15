namespace Metra.Api.Features.Records;

/// <summary>
/// Control-plane states for asynchronous recorder OCR and trace-digitization jobs.
/// This model is provider-neutral and performs no persistence, scheduling or I/O.
/// </summary>
public enum RecordDigitizationJobStatus
{
    Queued,
    Validating,
    Running,
    Succeeded,
    Failed,
    Cancelled
}

/// <summary>
/// Applies the documented job lifecycle without mutating the supplied state.
/// Terminal states are immutable; retries must be represented as a new attempt,
/// not by reopening a completed attempt.
/// </summary>
public static class RecordDigitizationJobState
{
    public static RecordDigitizationJobTransition Evaluate(
        RecordDigitizationJobStatus current,
        RecordDigitizationJobStatus requested)
    {
        if (!Enum.IsDefined(current) || !Enum.IsDefined(requested))
            return RecordDigitizationJobTransition.Rejected("unknown_job_state");

        if (current == requested)
            return RecordDigitizationJobTransition.Rejected("job_state_unchanged");

        var allowed = current switch
        {
            RecordDigitizationJobStatus.Queued =>
                requested is RecordDigitizationJobStatus.Validating
                    or RecordDigitizationJobStatus.Cancelled,

            RecordDigitizationJobStatus.Validating =>
                requested is RecordDigitizationJobStatus.Running
                    or RecordDigitizationJobStatus.Failed
                    or RecordDigitizationJobStatus.Cancelled,

            RecordDigitizationJobStatus.Running =>
                requested is RecordDigitizationJobStatus.Succeeded
                    or RecordDigitizationJobStatus.Failed
                    or RecordDigitizationJobStatus.Cancelled,

            _ => false
        };

        return allowed
            ? RecordDigitizationJobTransition.Accepted(current, requested)
            : RecordDigitizationJobTransition.Rejected(
                IsTerminal(current) ? "terminal_job_state" : "invalid_job_state_transition");
    }

    public static bool IsTerminal(RecordDigitizationJobStatus status) =>
        status is RecordDigitizationJobStatus.Succeeded
            or RecordDigitizationJobStatus.Failed
            or RecordDigitizationJobStatus.Cancelled;
}

public sealed record RecordDigitizationJobTransition(
    bool IsAllowed,
    RecordDigitizationJobStatus? From,
    RecordDigitizationJobStatus? To,
    string? ErrorCode)
{
    public static RecordDigitizationJobTransition Accepted(
        RecordDigitizationJobStatus from,
        RecordDigitizationJobStatus to) => new(true, from, to, null);

    public static RecordDigitizationJobTransition Rejected(string errorCode) =>
        new(false, null, null, errorCode);
}
