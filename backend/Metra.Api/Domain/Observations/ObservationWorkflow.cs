namespace Metra.Api.Domain.Observations;

public enum ObservationStatus
{
    Draft = 0,
    Submitted = 1,
    Returned = 2,
    Approved = 3
}

public enum ObservationAction
{
    Submit = 0,
    ReturnForCorrection = 1,
    Approve = 2,
    Resubmit = 3
}

public sealed record ObservationTransition(
    ObservationStatus From,
    ObservationAction Action,
    ObservationStatus To);

public sealed record ObservationWorkflowIssue(string Code, string Message);

public sealed record ObservationWorkflowResult(
    bool Succeeded,
    ObservationStatus Status,
    ObservationTransition? Transition,
    ObservationWorkflowIssue? Issue);

/// <summary>
/// Pure workflow rules. Authentication, station assignment, and permission checks
/// must be performed by the API/application layer before invoking this policy.
/// </summary>
public static class ObservationWorkflow
{
    public static ObservationWorkflowResult Apply(
        ObservationStatus currentStatus,
        ObservationAction action)
    {
        var next = (currentStatus, action) switch
        {
            (ObservationStatus.Draft, ObservationAction.Submit) => ObservationStatus.Submitted,
            (ObservationStatus.Returned, ObservationAction.Resubmit) => ObservationStatus.Submitted,
            (ObservationStatus.Submitted, ObservationAction.ReturnForCorrection) => ObservationStatus.Returned,
            (ObservationStatus.Submitted, ObservationAction.Approve) => ObservationStatus.Approved,
            _ => (ObservationStatus?)null
        };

        if (next is null)
        {
            return new(
                false,
                currentStatus,
                null,
                new("invalid_transition", "العملية غير مسموحة في حالة النشرة الحالية."));
        }

        return new(
            true,
            next.Value,
            new(currentStatus, action, next.Value),
            null);
    }
}