using Metra.Api.Domain.Identity;

namespace Metra.Api.Features.Identity;

/// <summary>
/// Trusted Supabase Auth identity derived from a fully validated bearer token.
/// AuthUserId must come from the immutable JWT sub claim, never request JSON.
/// </summary>
public sealed record RegistrationSubmissionActorContext(
    Guid AuthUserId,
    bool IsAuthenticated);

public interface IRegistrationSubmissionActorContextProvider
{
    Task<RegistrationSubmissionActorContext?> GetCurrentAsync(
        CancellationToken cancellationToken);
}

/// <summary>
/// Server-owned catalogue checks. Implementations must read the canonical,
/// active role and station catalogues; client labels are never authoritative.
/// </summary>
public interface IRegistrationSubmissionCatalogue
{
    Task<bool> IsRoleRequestableAsync(
        string roleCode,
        CancellationToken cancellationToken);

    Task<bool> IsStationSelectableAsync(
        string stationId,
        CancellationToken cancellationToken);
}

public sealed record SubmitRegistrationRequest(
    string FirstName,
    string FatherName,
    string LastName,
    string? Phone,
    string RequestedRoleCode,
    string RequestedStationId,
    string TermsVersion,
    bool TermsAccepted,
    string IdempotencyKey);

/// <summary>
/// Values for the single atomic METRA transaction. The store creates the
/// PendingApproval account, account_auth_links row, PendingStationApproval
/// request and submission audit event. It must not create role grants or
/// station assignments at this stage.
/// </summary>
public sealed record PendingRegistrationSubmission(
    Guid AuthUserId,
    string FirstName,
    string FatherName,
    string LastName,
    string? Phone,
    string RequestedRoleCode,
    string RequestedStationId,
    string TermsVersion,
    DateTimeOffset SubmittedAtUtc,
    string IdempotencyKey);

public enum RegistrationSubmissionCommitStatus
{
    Created = 0,
    AlreadyCreatedForSameIdempotencyKey = 1,
    AuthUserAlreadyLinked = 2,
    ExistingPendingRequest = 3,
    Conflict = 4
}

public sealed record RegistrationSubmissionCommitResult(
    RegistrationSubmissionCommitStatus Status,
    Guid? AccountId = null,
    Guid? RequestId = null);

public interface IRegistrationSubmissionStore
{
    /// <summary>
    /// Must use one transaction to verify the Auth user link is unused, create
    /// a PendingApproval account, link AuthUserId, create a
    /// PendingStationApproval request and append the submission audit event.
    /// It must enforce idempotency for (AuthUserId, IdempotencyKey), and must
    /// never persist credentials or create effective grants/assignments.
    /// </summary>
    Task<RegistrationSubmissionCommitResult> TryCreatePendingAsync(
        PendingRegistrationSubmission submission,
        CancellationToken cancellationToken);
}

public sealed record RegistrationSubmissionApplicationResult(
    bool Succeeded,
    string Code,
    string Message,
    Guid? AccountId = null,
    Guid? RequestId = null);

/// <summary>
/// Handles initial METRA onboarding after Supabase Auth has authenticated the
/// applicant. This is deliberately separate from identity relinking for active
/// METRA accounts and has no HTTP or database-provider dependency.
/// </summary>
public sealed class RegistrationSubmissionApplicationService(
    IRegistrationSubmissionActorContextProvider actorContextProvider,
    IRegistrationSubmissionCatalogue catalogue,
    IRegistrationSubmissionStore store,
    TimeProvider timeProvider)
{
    public async Task<RegistrationSubmissionApplicationResult> SubmitAsync(
        SubmitRegistrationRequest? command,
        CancellationToken cancellationToken = default)
    {
        if (command is null ||
            string.IsNullOrWhiteSpace(command.FirstName) ||
            string.IsNullOrWhiteSpace(command.FatherName) ||
            string.IsNullOrWhiteSpace(command.LastName) ||
            string.IsNullOrWhiteSpace(command.RequestedRoleCode) ||
            string.IsNullOrWhiteSpace(command.RequestedStationId) ||
            string.IsNullOrWhiteSpace(command.TermsVersion) ||
            string.IsNullOrWhiteSpace(command.IdempotencyKey))
        {
            return Failure("invalid_registration", "بيانات طلب التسجيل غير مكتملة.");
        }

        if (!command.TermsAccepted)
            return Failure("terms_not_accepted", "يجب الموافقة على شروط التسجيل.");

        var actor = await actorContextProvider.GetCurrentAsync(cancellationToken);
        if (actor is not { IsAuthenticated: true } ||
            actor.AuthUserId == Guid.Empty)
        {
            return Failure("unauthenticated", "يجب تسجيل الدخول عبر مزود الهوية أولاً.");
        }

        if (!await catalogue.IsRoleRequestableAsync(
            command.RequestedRoleCode, cancellationToken))
        {
            return Failure("role_not_available", "الدور المطلوب غير متاح للتسجيل.");
        }

        if (!await catalogue.IsStationSelectableAsync(
            command.RequestedStationId, cancellationToken))
        {
            return Failure("station_not_available", "المحطة المطلوبة غير متاحة للتسجيل.");
        }

        var submission = new PendingRegistrationSubmission(
            actor.AuthUserId,
            command.FirstName.Trim(),
            command.FatherName.Trim(),
            command.LastName.Trim(),
            NormalizeOptional(command.Phone),
            command.RequestedRoleCode,
            command.RequestedStationId,
            command.TermsVersion,
            timeProvider.GetUtcNow(),
            command.IdempotencyKey);

        var result = await store.TryCreatePendingAsync(submission, cancellationToken);

        return result.Status switch
        {
            RegistrationSubmissionCommitStatus.Created
                when HasIdentifiers(result) => Success(result),
            RegistrationSubmissionCommitStatus.AlreadyCreatedForSameIdempotencyKey
                when HasIdentifiers(result) => Success(result, alreadySubmitted: true),
            RegistrationSubmissionCommitStatus.AuthUserAlreadyLinked => Failure(
                "auth_user_already_linked",
                "حساب الهوية مرتبط بحساب METRA بالفعل."),
            RegistrationSubmissionCommitStatus.ExistingPendingRequest => Failure(
                "registration_already_pending",
                "يوجد طلب تسجيل قيد المراجعة لهذا الحساب."),
            RegistrationSubmissionCommitStatus.Conflict => Failure(
                "registration_submission_conflict",
                "تعذر تسجيل الطلب بسبب تعارض متزامن. أعد تحميل الحالة وحاول مجدداً."),
            _ => Failure(
                "registration_submission_failed",
                "تعذر إنشاء طلب التسجيل.")
        };
    }

    private static bool HasIdentifiers(RegistrationSubmissionCommitResult result)
        => result.AccountId is { } accountId &&
           accountId != Guid.Empty &&
           result.RequestId is { } requestId &&
           requestId != Guid.Empty;

    private static RegistrationSubmissionApplicationResult Success(
        RegistrationSubmissionCommitResult result,
        bool alreadySubmitted = false)
        => new(
            true,
            alreadySubmitted ? "registration_already_submitted" : "registration_submitted",
            alreadySubmitted
                ? "تم استرجاع طلب التسجيل السابق."
                : "تم إرسال طلب التسجيل للمراجعة.",
            result.AccountId,
            result.RequestId);

    private static RegistrationSubmissionApplicationResult Failure(
        string code,
        string message)
        => new(false, code, message);

    private static string? NormalizeOptional(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
