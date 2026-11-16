namespace Metra.Api.Domain.Observations;

public enum ObservationPermission
{
    Create = 0,
    EditOwnDraft = 1,
    Submit = 2,
    Review = 3,
    ReturnForCorrection = 4,
    Approve = 5,
    /// <summary>
    /// Explicit station-scoped archive read. Never inferred from role or authority membership.
    /// Grant must name a single station. Station A grant does not authorize station B.
    /// </summary>
    ArchiveRead = 6
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
/// <summary>
/// Station-scoped observation archive authorization.
/// Approved policy (Stage B): archive read is an explicit per-station grant only.
/// Role membership and authority membership never imply archive access.
/// A grant for station A never authorizes station B, even inside the same authority.
/// </summary>
public static class ObservationArchiveAuthorizationPolicy
{
    public static ObservationAuthorizationResult AuthorizeArchiveRead(
        ObservationActorContext? actor,
        string requestedStationId)
    {
        if (actor is null || string.IsNullOrWhiteSpace(actor.UserId))
            return new(false, "unauthenticated", "يجب تسجيل الدخول أولاً.");

        if (string.IsNullOrWhiteSpace(requestedStationId))
            return new(false, "station_required", "يجب تحديد المحطة المطلوب قراءة أرشيفها.");

        if (!actor.HasActiveStationAssignment)
            return new(false, "inactive_station_assignment", "لا يوجد تكليف فعّال للمستخدم بالمحطة.");

        if (string.IsNullOrWhiteSpace(actor.StationId) ||
            !string.Equals(actor.StationId, requestedStationId, StringComparison.Ordinal))
            return new(false, "station_scope_violation",
                "منحة أرشيف محطة أخرى لا تمنح الوصول إلى هذه المحطة، حتى لو كانت ضمن الجهة نفسها.");

        if (actor.Permissions is null || !actor.Permissions.Contains(ObservationPermission.ArchiveRead))
            return new(false, "archive_permission_denied",
                "قراءة الأرشيف تتطلب منحة صريحة observation.archive.read لهذه المحطة تحديداً.");

        return new(true, null, null);
    }
}
