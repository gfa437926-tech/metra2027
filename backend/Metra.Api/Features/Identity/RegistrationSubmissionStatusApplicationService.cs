using Metra.Api.Domain.Identity;

namespace Metra.Api.Features.Identity;

public sealed record RegistrationSubmissionStatusSnapshot(
    Guid RequestId,
    RegistrationApprovalStatus Status,
    DateTimeOffset SubmittedAtUtc,
    DateTimeOffset UpdatedAtUtc);

public interface IRegistrationSubmissionStatusStore
{
    Task<RegistrationSubmissionStatusSnapshot?> FindOwnStatusAsync(
        Guid authUserId,
        Guid requestId,
        CancellationToken cancellationToken);
}

public sealed record RegistrationSubmissionStatusResponse(
    Guid RequestId,
    string Status,
    string StatusLabel,
    DateTimeOffset SubmittedAtUtc,
    DateTimeOffset UpdatedAtUtc);

public sealed record RegistrationSubmissionStatusApplicationResult(
    bool Succeeded,
    string Code,
    string Message,
    RegistrationSubmissionStatusResponse? Value = null);

/// <summary>
/// Reads a minimal status projection only for the authenticated applicant.
/// Reviewer identities, internal notes and other applicants' data are excluded.
/// </summary>
public sealed class RegistrationSubmissionStatusApplicationService(
    IRegistrationSubmissionActorContextProvider actorContextProvider,
    IRegistrationSubmissionStatusStore store)
{
    public async Task<RegistrationSubmissionStatusApplicationResult> ReadOwnAsync(
        Guid requestId,
        CancellationToken cancellationToken = default)
    {
        if (requestId == Guid.Empty)
            return Failure("invalid_request_id", "معرّف طلب التسجيل غير صالح.");

        var actor = await actorContextProvider.GetCurrentAsync(cancellationToken);
        if (actor is not { IsAuthenticated: true } || actor.AuthUserId == Guid.Empty)
            return Failure("unauthenticated", "يجب تسجيل الدخول عبر مزود الهوية أولاً.");

        var snapshot = await store.FindOwnStatusAsync(
            actor.AuthUserId, requestId, cancellationToken);
        if (snapshot is null)
            return Failure("registration_request_not_found", "طلب التسجيل غير موجود.");

        if (snapshot.RequestId != requestId ||
            !Enum.IsDefined(snapshot.Status) ||
            snapshot.SubmittedAtUtc.Offset != TimeSpan.Zero ||
            snapshot.UpdatedAtUtc.Offset != TimeSpan.Zero ||
            snapshot.UpdatedAtUtc < snapshot.SubmittedAtUtc)
            return Failure("registration_status_unavailable", "تعذر التحقق من حالة طلب التسجيل.");

        var (status, label) = snapshot.Status switch
        {
            RegistrationApprovalStatus.PendingStationApproval =>
                ("pending_station_approval", "بانتظار موافقة رئيس المحطة"),
            RegistrationApprovalStatus.PendingSystemApproval =>
                ("pending_system_approval", "بانتظار موافقة إدارة النظام"),
            RegistrationApprovalStatus.Active =>
                ("active", "تم اعتماد الحساب"),
            RegistrationApprovalStatus.Rejected =>
                ("rejected", "تم رفض طلب التسجيل"),
            _ => throw new InvalidOperationException("Unknown registration approval status.")
        };

        return new(
            true,
            "registration_status_loaded",
            "تم تحميل حالة طلب التسجيل.",
            new(snapshot.RequestId, status, label, snapshot.SubmittedAtUtc, snapshot.UpdatedAtUtc));
    }

    private static RegistrationSubmissionStatusApplicationResult Failure(
        string code,
        string message)
        => new(false, code, message);
}
