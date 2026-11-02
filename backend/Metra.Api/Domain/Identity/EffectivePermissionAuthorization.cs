namespace Metra.Api.Domain.Identity;

/// <summary>
/// Authorization-relevant METRA account lifecycle. Only Active accounts may
/// exercise grants; pending and suspended accounts fail closed.
/// </summary>
public enum MetraAccountAccessState
{
    PendingApproval = 0,
    Active = 1,
    Suspended = 2,
    Disabled = 3
}

/// <summary>
/// A permission grant is independent of a role label. A null StationId means
/// an explicitly global grant; it is never treated as a wildcard for a
/// station-scoped request.
/// </summary>
public sealed record MetraPermissionGrant(
    string PermissionCode,
    string? StationId,
    DateTimeOffset ValidFromUtc,
    DateTimeOffset? ValidUntilUtc,
    DateTimeOffset? RevokedAtUtc)
{
    public bool IsEffectiveAt(DateTimeOffset instantUtc)
    {
        if (string.IsNullOrWhiteSpace(PermissionCode) ||
            ValidFromUtc.Offset != TimeSpan.Zero ||
            ValidUntilUtc is { } end && (end.Offset != TimeSpan.Zero || end <= ValidFromUtc) ||
            RevokedAtUtc is { } revoked && (revoked.Offset != TimeSpan.Zero || revoked < ValidFromUtc))
            return false;

        return instantUtc >= ValidFromUtc &&
               (ValidUntilUtc is null || instantUtc < ValidUntilUtc.Value) &&
               (RevokedAtUtc is null || instantUtc < RevokedAtUtc.Value);
    }
}

/// <summary>
/// A station assignment grants scope, not a permission. It must be combined
/// with a matching permission grant for station-scoped operations.
/// </summary>
public sealed record MetraStationAssignment(
    string StationId,
    DateTimeOffset ValidFromUtc,
    DateTimeOffset? ValidUntilUtc,
    DateTimeOffset? RevokedAtUtc)
{
    public bool IsEffectiveAt(DateTimeOffset instantUtc)
    {
        if (string.IsNullOrWhiteSpace(StationId) ||
            ValidFromUtc.Offset != TimeSpan.Zero ||
            ValidUntilUtc is { } end && (end.Offset != TimeSpan.Zero || end <= ValidFromUtc) ||
            RevokedAtUtc is { } revoked && (revoked.Offset != TimeSpan.Zero || revoked < ValidFromUtc))
            return false;

        return instantUtc >= ValidFromUtc &&
               (ValidUntilUtc is null || instantUtc < ValidUntilUtc.Value) &&
               (RevokedAtUtc is null || instantUtc < RevokedAtUtc.Value);
    }
}

public sealed record EffectivePermissionAuthorizationResult(
    bool IsAuthorized,
    string Code,
    string Message);

/// <summary>
/// Evaluates current effective access using server-loaded account, grants and
/// assignments. Role names and client-provided claims are intentionally absent.
/// A station operation requires BOTH an exact station-scoped permission grant
/// and an effective assignment to that same station.
/// A global operation requires an explicit global grant (StationId = null).
/// </summary>
public static class EffectivePermissionAuthorization
{
    public static EffectivePermissionAuthorizationResult Authorize(
        MetraAccountAccessState accountState,
        string? requiredPermissionCode,
        string? stationId,
        IEnumerable<MetraPermissionGrant>? permissionGrants,
        IEnumerable<MetraStationAssignment>? stationAssignments,
        DateTimeOffset instantUtc)
    {
        if (!Enum.IsDefined(accountState))
            return Deny("account_state_invalid", "حالة الحساب غير معروفة.");

        if (accountState != MetraAccountAccessState.Active)
            return Deny("account_not_active", "الحساب غير نشط ولا يملك صلاحية تنفيذ العملية.");

        if (string.IsNullOrWhiteSpace(requiredPermissionCode))
            return Deny("permission_required", "رمز الصلاحية المطلوبة غير صالح.");

        if (permissionGrants is null)
            return Deny("permission_not_granted", "لا توجد صلاحية فعالة لتنفيذ العملية.");

        var hasPermission = permissionGrants.Any(grant =>
            grant is not null &&
            string.Equals(grant.PermissionCode, requiredPermissionCode, StringComparison.Ordinal) &&
            string.Equals(grant.StationId, stationId, StringComparison.Ordinal) &&
            grant.IsEffectiveAt(instantUtc));

        if (!hasPermission)
            return Deny("permission_not_granted", "لا توجد صلاحية فعالة ومطابقة لنطاق العملية.");

        if (stationId is null)
            return new(true, "authorized", "تم التحقق من الصلاحية العامة.");

        if (string.IsNullOrWhiteSpace(stationId))
            return Deny("station_scope_invalid", "نطاق المحطة غير صالح.");

        if (stationAssignments is null)
            return Deny("station_assignment_required", "لا يوجد إسناد محطة فعال.");

        var hasAssignment = stationAssignments.Any(assignment =>
            assignment is not null &&
            string.Equals(assignment.StationId, stationId, StringComparison.Ordinal) &&
            assignment.IsEffectiveAt(instantUtc));

        return hasAssignment
            ? new(true, "authorized", "تم التحقق من الصلاحية وإسناد المحطة.")
            : Deny("station_assignment_required", "لا يوجد إسناد فعال لهذه المحطة.");
    }

    private static EffectivePermissionAuthorizationResult Deny(string code, string message)
        => new(false, code, message);
}
