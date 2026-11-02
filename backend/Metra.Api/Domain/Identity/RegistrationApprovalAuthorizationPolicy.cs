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
    RegistrationApprovalStatus Status);

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

        if (!actor.IsActive)
            return Deny("inactive_actor", "حساب المستخدم غير نشط.");

        if (string.Equals(actor.UserId, request.RequestedByUserId, StringComparison.Ordinal))
            return Deny("self_approval_forbidden", "لا يمكن للمستخدم اعتماد طلب التسجيل الخاص به.");

        return request.Status switch
        {
            RegistrationApprovalStatus.PendingStationApproval
                => AuthorizeStationDecision(actor, request),
            RegistrationApprovalStatus.PendingSystemApproval
                => AuthorizeSystemDecision(actor),
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
        RegistrationApprovalActorContext actor)
    {
        if (!actor.CanApproveSystemRegistrations)
            return Deny("system_approval_permission_required", "لا يملك المستخدم صلاحية الاعتماد النهائي للنظام.");

        return new(true, null, null);
    }

    private static RegistrationApprovalAuthorizationResult Deny(string code, string message)
        => new(false, code, message);
}
