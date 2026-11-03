namespace Metra.Api.Domain.Identity;

/// <summary>
/// Actor facts must be resolved by trusted server code from the authenticated
/// identity and authoritative METRA assignments. Never construct this context
/// from request JSON, query parameters or browser storage.
/// </summary>
public sealed record RegistrationApprovalActorContext(
    string UserId,
    bool IsActive,
    bool CanApproveStationRegistrations,
    IReadOnlySet<string> StationManagerStationIds,
    bool CanApproveSystemRegistrations);

/// <summary>
/// Minimal persisted request facts required for approval authorization.
/// </summary>
public sealed record RegistrationApprovalRequestContext(
    string RequestId,
    string RequestedByUserId,
    string RequestedStationId,
    RegistrationApprovalStatus Status,
    string? StationApprovedByUserId = null);

public sealed record RegistrationApprovalAuthorizationResult(
    bool IsAuthorized,
    string? ErrorCode,
    string? Message);

public static class RegistrationApprovalAuthorizationPolicy
{
    public static RegistrationApprovalAuthorizationResult Authorize(
        RegistrationApprovalActorContext? actor,
        RegistrationApprovalRequestContext? request)
    {
        if (actor is null || string.IsNullOrWhiteSpace(actor.UserId))
            return Deny("unauthenticated", "يجب تسجيل الدخول أولاً.");

        if (request is null || string.IsNullOrWhiteSpace(request.RequestId))
            return Deny("registration_request_not_found", "طلب التسجيل غير موجود.");

        // Missing applicant identity would make the self-approval check fail open.
        // Missing station scope makes a station-stage decision unverifiable.
        if (string.IsNullOrWhiteSpace(request.RequestedByUserId) ||
            string.IsNullOrWhiteSpace(request.RequestedStationId))
            return Deny("registration_request_invalid", "بيانات طلب التسجيل لا تسمح بالتحقق الآمن من الاعتماد.");

        if (!actor.IsActive)
            return Deny("inactive_actor", "حساب المستخدم غير نشط.");

        if (string.Equals(actor.UserId, request.RequestedByUserId, StringComparison.Ordinal))
            return Deny("self_approval_forbidden", "لا يمكن للمستخدم اعتماد طلب التسجيل الخاص به.");

        return request.Status switch
        {
            RegistrationApprovalStatus.PendingStationApproval
                => AuthorizeStationDecision(actor, request),
            RegistrationApprovalStatus.PendingSystemApproval
                => AuthorizeSystemDecision(actor, request),
            _ => Deny("approval_not_pending", "طلب التسجيل ليس بانتظار قرار اعتماد.")
        };
    }

    private static RegistrationApprovalAuthorizationResult AuthorizeStationDecision(
        RegistrationApprovalActorContext actor,
        RegistrationApprovalRequestContext request)
    {
        if (!actor.CanApproveStationRegistrations)
            return Deny("station_approval_permission_required", "لا يملك المستخدم صلاحية اعتماد طلبات المحطات.");

        if (actor.StationManagerStationIds is null ||
            !actor.StationManagerStationIds.Contains(request.RequestedStationId))
            return Deny("station_scope_violation", "لا يملك المستخدم صلاحية اعتماد طلبات هذه المحطة.");

        return new(true, null, null);
    }

    private static RegistrationApprovalAuthorizationResult AuthorizeSystemDecision(
        RegistrationApprovalActorContext actor,
        RegistrationApprovalRequestContext request)
    {
        // The second stage must be backed by a persisted first-stage actor.
        // Missing evidence must never turn a corrupted status into final approval.
        if (string.IsNullOrWhiteSpace(request.StationApprovedByUserId))
            return Deny("station_approval_evidence_missing", "لا يوجد سجل موثق لاعتماد مدير المحطة.");

        // Enforce separation of duties: the station reviewer and system approver
        // must be two distinct METRA accounts, not merely two permission checks.
        if (string.Equals(actor.UserId, request.StationApprovedByUserId, StringComparison.Ordinal))
            return Deny("approval_separation_of_duties_violation", "يجب أن يكون الاعتماد النهائي من مسؤول مختلف عن معتمد المحطة.");

        if (!actor.CanApproveSystemRegistrations)
            return Deny("system_approval_permission_required", "لا يملك المستخدم صلاحية الاعتماد النهائي للنظام.");

        return new(true, null, null);
    }

    private static RegistrationApprovalAuthorizationResult Deny(string code, string message)
        => new(false, code, message);
}
