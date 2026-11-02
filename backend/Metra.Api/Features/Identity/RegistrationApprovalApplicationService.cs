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
/// one transaction to reload and lock the current request and actor authorization
/// facts, then revalidate actor activity, explicit stage permission, self-approval
/// prohibition, and (for station review) the current station assignment. For
/// final review it must also verify persisted station-stage evidence and enforce
/// that the system approver differs from the station approver. It must serialize
/// against concurrent permission/assignment revocation so stale facts
/// from the earlier application-layer check cannot authorize a decision.
/// Within that same transaction it must compare-and-set expectedStatus and append
/// the immutable decision audit event. On final approval only, it must activate
/// the account and create the approved role grant and station assignment atomically.
/// It must return Conflict when the request state or authorization facts changed.
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
    private const int MaximumRequestIdLength = 128;

    public async Task<RegistrationApprovalApplicationResult> DecideAsync(
        SubmitRegistrationApprovalDecision command,
        CancellationToken cancellationToken = default)
    {
        if (command is null || string.IsNullOrWhiteSpace(command.RequestId))
            return Failure("invalid_request", "معرّف طلب التسجيل مطلوب.");

        var requestId = command.RequestId.Trim();
        if (requestId.Length > MaximumRequestIdLength ||
            requestId.Any(char.IsControl) ||
            requestId.Any(c => !(char.IsAsciiLetterOrDigit(c) || c is '-' or '_' or '.')))
            return Failure("invalid_request", "معرّف طلب التسجيل غير صالح.");

        if (!Enum.IsDefined(command.Decision))
            return Failure("invalid_decision", "قرار الاعتماد غير معروف.");

        if (command.Note?.Length > MaximumNoteLength)
            return Failure("note_too_long", "ملاحظة القرار تتجاوز الحد المسموح.");
        if (command.Note?.Any(char.IsControl) == true)
            return Failure("note_invalid", "ملاحظة القرار تحتوي على محارف غير مسموح بها.");

        var actor = await actorContextProvider.GetCurrentActorAsync(cancellationToken);
        if (actor is null || string.IsNullOrWhiteSpace(actor.UserId))
            return Failure("unauthenticated", "يجب تسجيل الدخول أولاً.");
        if (actor.UserId != actor.UserId.Trim() ||
            actor.UserId.Length > MaximumRequestIdLength ||
            actor.UserId.Any(char.IsControl))
            return Failure("actor_context_invalid", "تعذر التحقق من هوية منفذ القرار.");

        var request = await store.FindRequestAsync(requestId, cancellationToken);
        if (request is null)
            return Failure("registration_request_not_found", "طلب التسجيل غير موجود.");
        if (request.RequestId != requestId ||
            string.IsNullOrWhiteSpace(request.RequestId) ||
            request.RequestId.Any(char.IsControl))
            return Failure("registration_request_invalid", "بيانات طلب التسجيل غير صالحة.");

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
            requestId,
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
