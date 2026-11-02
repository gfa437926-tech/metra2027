namespace Metra.Api.Features.Registration;

public enum RegistrationRequestState
{
    PendingStationApproval = 0,
    PendingSystemApproval = 1,
    Active = 2,
    Rejected = 3
}

public enum RegistrationApprovalStage
{
    Station = 0,
    System = 1
}

public enum RegistrationApprovalDecision
{
    Approve = 0,
    Reject = 1
}

/// <summary>
/// Facts resolved by the API from the authenticated principal and authoritative
/// permission/assignment services. Never construct these values from request JSON.
/// </summary>
public sealed record RegistrationApprovalActorFacts(
    string MetraUserId,
    bool HasStationApprovalPermission,
    bool HasSystemApprovalPermission,
    IReadOnlySet<string> ActiveStationIds);

/// <summary>
/// Minimal persisted request facts needed to make a decision. The repository must
/// load this snapshot under a transaction/lock before calling the workflow.
/// </summary>
public sealed record RegistrationRequestApprovalFacts(
    string RequestId,
    string ApplicantMetraUserId,
    string RequestedStationId,
    RegistrationRequestState State);

public sealed record RegistrationApprovalAuditEvent(
    string RequestId,
    string ActorMetraUserId,
    RegistrationApprovalStage Stage,
    RegistrationApprovalDecision Decision,
    RegistrationRequestState PreviousState,
    RegistrationRequestState NextState,
    DateTimeOffset DecidedAtUtc,
    string? Note);

/// <summary>
/// A pure domain transition. The caller must persist the new state and audit event
/// atomically. When NextState is Active, provisioning of approved grants and the
/// station assignment must occur in that same transaction.
/// </summary>
public sealed record RegistrationApprovalTransition(
    RegistrationRequestApprovalFacts UpdatedRequest,
    RegistrationApprovalAuditEvent AuditEvent);

/// <summary>
/// Implements the approved two-stage approval order without depending on a
/// database provider. Authorization facts must be resolved server-side before use.
/// </summary>
public sealed class RegistrationApprovalWorkflow(TimeProvider timeProvider)
{
    public RegistrationApprovalTransition DecideAtStation(
        RegistrationRequestApprovalFacts request,
        RegistrationApprovalActorFacts actor,
        RegistrationApprovalDecision decision,
        string? note = null)
    {
        ValidateCommon(request, actor, decision);

        if (request.State != RegistrationRequestState.PendingStationApproval)
        {
            throw new InvalidOperationException(
                "The request is not awaiting station approval.");
        }

        if (!actor.HasStationApprovalPermission)
        {
            throw new UnauthorizedAccessException(
                "The actor lacks the station-approval permission.");
        }

        if (!actor.ActiveStationIds.Contains(request.RequestedStationId))
        {
            throw new UnauthorizedAccessException(
                "The actor has no active assignment for the requested station.");
        }

        var nextState = decision == RegistrationApprovalDecision.Approve
            ? RegistrationRequestState.PendingSystemApproval
            : RegistrationRequestState.Rejected;

        return CreateTransition(
            request, actor, RegistrationApprovalStage.Station, decision, nextState, note);
    }

    public RegistrationApprovalTransition DecideAtSystem(
        RegistrationRequestApprovalFacts request,
        RegistrationApprovalActorFacts actor,
        RegistrationApprovalDecision decision,
        string? note = null)
    {
        ValidateCommon(request, actor, decision);

        if (request.State != RegistrationRequestState.PendingSystemApproval)
        {
            throw new InvalidOperationException(
                "The request is not awaiting system approval.");
        }

        if (!actor.HasSystemApprovalPermission)
        {
            throw new UnauthorizedAccessException(
                "The actor lacks the system-approval permission.");
        }

        var nextState = decision == RegistrationApprovalDecision.Approve
            ? RegistrationRequestState.Active
            : RegistrationRequestState.Rejected;

        return CreateTransition(
            request, actor, RegistrationApprovalStage.System, decision, nextState, note);
    }

    private RegistrationApprovalTransition CreateTransition(
        RegistrationRequestApprovalFacts request,
        RegistrationApprovalActorFacts actor,
        RegistrationApprovalStage stage,
        RegistrationApprovalDecision decision,
        RegistrationRequestState nextState,
        string? note)
    {
        var decidedAt = timeProvider.GetUtcNow();
        var updated = request with { State = nextState };
        var auditEvent = new RegistrationApprovalAuditEvent(
            request.RequestId,
            actor.MetraUserId,
            stage,
            decision,
            request.State,
            nextState,
            decidedAt,
            NormalizeNote(note));

        return new RegistrationApprovalTransition(updated, auditEvent);
    }

    private static void ValidateCommon(
        RegistrationRequestApprovalFacts request,
        RegistrationApprovalActorFacts actor,
        RegistrationApprovalDecision decision)
    {
        ArgumentNullException.ThrowIfNull(request);
        ArgumentNullException.ThrowIfNull(actor);
        ArgumentNullException.ThrowIfNull(actor.ActiveStationIds);

        ArgumentException.ThrowIfNullOrWhiteSpace(request.RequestId);
        ArgumentException.ThrowIfNullOrWhiteSpace(request.ApplicantMetraUserId);
        ArgumentException.ThrowIfNullOrWhiteSpace(request.RequestedStationId);
        ArgumentException.ThrowIfNullOrWhiteSpace(actor.MetraUserId);

        if (!Enum.IsDefined(decision))
        {
            throw new ArgumentOutOfRangeException(nameof(decision));
        }

        if (string.Equals(
            request.ApplicantMetraUserId,
            actor.MetraUserId,
            StringComparison.Ordinal))
        {
            throw new UnauthorizedAccessException(
                "An applicant cannot approve or reject their own registration request.");
        }
    }

    private static string? NormalizeNote(string? note)
    {
        var normalized = note?.Trim();
        return string.IsNullOrEmpty(normalized) ? null : normalized;
    }
}
