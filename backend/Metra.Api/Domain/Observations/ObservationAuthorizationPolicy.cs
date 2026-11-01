namespace Metra.Api.Domain.Observations;

public enum ObservationPermission
{
    Create = 0,
    EditOwnDraft = 1,
    Submit = 2,
    Review = 3,
    ReturnForCorrection = 4,
    Approve = 5
}

public sealed record ObservationActorContext(
    string UserId,
    string StationId,
    bool HasActiveStationAssignment,
    IReadOnlySet<ObservationPermission> Permissions);

public sealed record ObservationResourceContext(
    string StationId,
    string CreatedByUserId);

public sealed record ObservationAuthorizationResult(
    bool IsAuthorized,
    string? ErrorCode,
    string? Message);

/// <summary>
/// Authorization policy for observation operations. Inputs must be populated
/// from authenticated server-side identity and persisted station assignments,
/// never from client-supplied role or station fields.
/// </summary>
public static class ObservationAuthorizationPolicy
{
    public static ObservationAuthorizationResult Authorize(
        ObservationActorContext? actor,
        ObservationResourceContext? observation,
        ObservationPermission permission)
    {
        if (actor is null || string.IsNullOrWhiteSpace(actor.UserId))
            return Deny("unauthenticated", "يجب تسجيل الدخول أولاً.");

        if (observation is null || string.IsNullOrWhiteSpace(observation.StationId))
            return Deny("observation_not_found", "النشرة المطلوبة غير موجودة.");

        if (!actor.HasActiveStationAssignment)
            return Deny("inactive_station_assignment", "لا يوجد تكليف فعّال للمستخدم بمحطة.");

        if (string.IsNullOrWhiteSpace(actor.StationId) ||
            !string.Equals(actor.StationId, observation.StationId, StringComparison.Ordinal))
            return Deny("station_scope_violation", "لا يملك المستخدم تكليفاً فعّالاً بمحطة هذه النشرة.");

        if (actor.Permissions is null || !actor.Permissions.Contains(permission))
            return Deny("permission_denied", "لا يملك المستخدم الصلاحية المطلوبة.");

        if (permission is ObservationPermission.EditOwnDraft or ObservationPermission.Submit &&
            !string.Equals(actor.UserId, observation.CreatedByUserId, StringComparison.Ordinal))
            return Deny("not_observation_owner", "يمكن تنفيذ هذه العملية على النشرة التي أنشأها المستخدم فقط.");

        return new(true, null, null);
    }

    private static ObservationAuthorizationResult Deny(string code, string message)
        => new(false, code, message);
}