using Metra.Api.Domain.Identity;

namespace Metra.Api.Features.Identity;

/// <summary>
/// Supplies actor facts from the authenticated server request and authoritative
/// METRA account/assignment data. Implementations must never trust client fields.
/// </summary>
public interface IRegistrationApprovalActorContextProvider
{
    Task<RegistrationApprovalActorContext?> GetCurrentActorAsync(CancellationToken cancellationToken);
}

/// <summary>
/// Persistence boundary for approval decisions. TryCommitDecisionAsync must use
/// an atomic compare-and-set against expectedStatus and persist the status change,
/// decision audit event, and (for final approval) account activation/assignment
/// changes in one database transaction. It must return Conflict when the stored
/// status no longer equals expectedStatus.
/// </summary>
public interface IRegistrationApprovalStore
{
    Task<RegistrationApprovalRequestContext?> FindRequestAsync(
        string requestId,
        CancellationToken cancellationToken);

    Task<RegistrationApprovalCommitResult> TryCommitDecisionAsync(
        string requestId,
        RegistrationApprovalStatus expectedStatus,
        RegistrationApprovalTransition transition,
        string actorUserId,
        string? note,
        CancellationToken cancellationToken);
}

public enum RegistrationApprovalCommitResult
{
    Committed = 0,
    NotFound = 1,
    Conflict = 2
}

public sealed record SubmitRegistrationApprovalDecision(
    string RequestId,
    RegistrationApprovalDecision Decision,
    string? Note);

public sealed record RegistrationApprovalApplicationResult(
    bool Succeeded,
    string Code,
    string Message,
    RegistrationApprovalStatus? CurrentStatus = null);

/// <summary>
/// Coordinates authorization, state transition and atomic persistence. This
/// service intentionally has no HTTP, identity-provider or database dependency.
/// </summary>
public sealed class RegistrationApprovalApplicationService(
    IRegistrationApprovalActorContextProvider actorContextProvider,
    IRegistrationApprovalStore store)
{
    private const int MaximumNoteLength = 2000;

    public async Task<RegistrationApprovalApplicationResult> DecideAsync(
        SubmitRegistrationApprovalDecision command,
        CancellationToken cancellationToken = default)
    {
        if (command is null || string.IsNullOrWhiteSpace(command.RequestId))
            return Failure("invalid_request", "معرّف طلب التسجيل مطلوب.");

        if (command.Note?.Length > MaximumNoteLength)
            return Failure("note_too_long", "ملاحظة القرار تتجاوز الحد المسموح.");

        var actor = await actorContextProvider.GetCurrentActorAsync(cancellationToken);
        if (actor is null || string.IsNullOrWhiteSpace(actor.UserId))
            return Failure("unauthenticated", "يجب تسجيل الدخول أولاً.");

        var request = await store.FindRequestAsync(command.RequestId, cancellationToken);
        if (request is null)
            return Failure("registration_request_not_found", "طلب التسجيل غير موجود.");

        var authorization = RegistrationApprovalAuthorizationPolicy.Authorize(actor, request);
        if (!authorization.IsAuthorized)
            return Failure(authorization.ErrorCode!, authorization.Message!, request.Status);

        var transition = RegistrationApprovalWorkflow.Apply(request.Status, command.Decision);
        if (!transition.Succeeded || transition.Transition is null)
            return Failure(
                transition.Issue?.Code ?? "invalid_transition",
                transition.Issue?.Message ?? "تعذر تنفيذ انتقال حالة طلب التسجيل.",
                request.Status);

        var commit = await store.TryCommitDecisionAsync(
            request.RequestId,
            request.Status,
            transition.Transition,
            actor.UserId,
            command.Note,
            cancellationToken);

        return commit switch
        {
            RegistrationApprovalCommitResult.Committed => new(
                true,
                "decision_recorded",
                "تم تسجيل قرار الاعتماد.",
                transition.Status),
            RegistrationApprovalCommitResult.NotFound => Failure(
                "registration_request_not_found",
                "طلب التسجيل غير موجود."),
            RegistrationApprovalCommitResult.Conflict => Failure(
                "approval_state_conflict",
                "تغيرت حالة طلب التسجيل بواسطة عملية أخرى. أعد تحميل الطلب قبل المحاولة."),
            _ => Failure("approval_commit_failed", "تعذر حفظ قرار الاعتماد.")
        };
    }

    private static RegistrationApprovalApplicationResult Failure(
        string code,
        string message,
        RegistrationApprovalStatus? status = null)
        => new(false, code, message, status);
}
