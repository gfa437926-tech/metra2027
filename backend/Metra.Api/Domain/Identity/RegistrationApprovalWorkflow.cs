namespace Metra.Api.Domain.Identity;

public enum RegistrationApprovalStatus
{
    PendingStationApproval = 0,
    PendingSystemApproval = 1,
    Active = 2,
    Rejected = 3
}

public enum RegistrationApprovalDecision
{
    Approve = 0,
    Reject = 1
}

public enum RegistrationApprovalStage
{
    Station = 0,
    System = 1
}

public sealed record RegistrationApprovalTransition(
    RegistrationApprovalStatus From,
    RegistrationApprovalDecision Decision,
    RegistrationApprovalStage Stage,
    RegistrationApprovalStatus To);

public sealed record RegistrationApprovalIssue(string Code, string Message);

public sealed record RegistrationApprovalResult(
    bool Succeeded,
    RegistrationApprovalStatus Status,
    RegistrationApprovalTransition? Transition,
    RegistrationApprovalIssue? Issue);

/// <summary>
/// Pure two-stage registration lifecycle rules. Persistence, authenticated actor
/// resolution, authorization and transactional audit recording belong to the
/// application/API layer and must run before/around this state transition.
/// </summary>
public static class RegistrationApprovalWorkflow
{
    public static RegistrationApprovalResult Apply(
        RegistrationApprovalStatus currentStatus,
        RegistrationApprovalDecision decision)
    {
        var transition = (currentStatus, decision) switch
        {
            (RegistrationApprovalStatus.PendingStationApproval, RegistrationApprovalDecision.Approve)
                => (RegistrationApprovalStatus.PendingSystemApproval, RegistrationApprovalStage.Station),
            (RegistrationApprovalStatus.PendingStationApproval, RegistrationApprovalDecision.Reject)
                => (RegistrationApprovalStatus.Rejected, RegistrationApprovalStage.Station),
            (RegistrationApprovalStatus.PendingSystemApproval, RegistrationApprovalDecision.Approve)
                => (RegistrationApprovalStatus.Active, RegistrationApprovalStage.System),
            (RegistrationApprovalStatus.PendingSystemApproval, RegistrationApprovalDecision.Reject)
                => (RegistrationApprovalStatus.Rejected, RegistrationApprovalStage.System),
            _ => ((RegistrationApprovalStatus, RegistrationApprovalStage)?)null
        };

        if (transition is null)
        {
            return new(
                false,
                currentStatus,
                null,
                new("invalid_transition", "لا يمكن اتخاذ هذا القرار في حالة طلب التسجيل الحالية."));
        }

        var (nextStatus, stage) = transition.Value;
        return new(
            true,
            nextStatus,
            new(currentStatus, decision, stage, nextStatus),
            null);
    }
}
