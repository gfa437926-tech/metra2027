namespace Metra.Api.Security;

/// <summary>
/// A server-resolved authorization snapshot. Do not construct this from request
/// body fields or untrusted role claims; populate it from validated identity and
/// current database membership/assignment/permission records.
/// </summary>
public sealed record MetraAuthorizationSnapshot(
    string Subject,
    bool ProfileIsActive,
    bool MembershipIsActive,
    IReadOnlyList<MetraAuthorizationGrant> Grants);

/// <summary>
/// A single active role assignment and its explicit permissions. Scope values
/// intentionally use canonical identifiers: station, organization, global_read.
/// </summary>
public sealed record MetraAuthorizationGrant(
    string RoleCode,
    string ScopeType,
    Guid? StationId,
    Guid? OrganizationId,
    bool IsActive,
    IReadOnlySet<string> Permissions);

public enum MetraAuthorizationOutcome
{
    AllowedStationScope,
    AllowedGlobalRead,
    DeniedMissingIdentity,
    DeniedInactiveProfile,
    DeniedInactiveMembership,
    DeniedInvalidStation,
    DeniedPermissionMissing,
    DeniedScopeMismatch
}

public sealed record MetraAuthorizationDecision(
    bool Allowed,
    MetraAuthorizationOutcome Outcome)
{
    public static MetraAuthorizationDecision Deny(MetraAuthorizationOutcome outcome) => new(false, outcome);
    public static MetraAuthorizationDecision Allow(MetraAuthorizationOutcome outcome) => new(true, outcome);
}

/// <summary>
/// Fail-closed station read authorization shared by station-scoped API features.
/// Global visibility is deliberately limited to an explicit allow-list of read
/// permissions and the auditor/network-department-head roles. It never grants
/// write, approval, identity or platform-administration permissions.
/// </summary>
public static class MetraStationReadAuthorization
{
    private static readonly IReadOnlySet<string> GlobalReadRoles =
        new HashSet<string>(StringComparer.Ordinal)
        { "auditor", "network_department_head" };

    private static readonly IReadOnlySet<string> StationReadPermissions =
        new HashSet<string>(StringComparer.Ordinal)
        {
            "stations.read",
            "observations.read_station",
            "forecasts.read_station",
            "alerts.read_station",
            "recorder.read_station",
            "instruments.read_station"
        };

    private static readonly IReadOnlySet<string> GlobalReadPermissions =
        new HashSet<string>(StringComparer.Ordinal)
        {
            "stations.read_all",
            "observations.read_all",
            "audit.read_all",
            "forecasts.read_all",
            "alerts.read_all",
            "recorder.read_all",
            "instruments.read_all"
        };

    public static MetraAuthorizationDecision Evaluate(
        MetraAuthorizationSnapshot? actor,
        Guid requestedStationId,
        string requiredReadPermission)
    {
        if (actor is null || string.IsNullOrWhiteSpace(actor.Subject))
            return MetraAuthorizationDecision.Deny(MetraAuthorizationOutcome.DeniedMissingIdentity);

        if (!actor.ProfileIsActive)
            return MetraAuthorizationDecision.Deny(MetraAuthorizationOutcome.DeniedInactiveProfile);

        if (!actor.MembershipIsActive)
            return MetraAuthorizationDecision.Deny(MetraAuthorizationOutcome.DeniedInactiveMembership);

        if (requestedStationId == Guid.Empty)
            return MetraAuthorizationDecision.Deny(MetraAuthorizationOutcome.DeniedInvalidStation);

        if (string.IsNullOrWhiteSpace(requiredReadPermission) ||
            !IsCanonicalPermission(requiredReadPermission) ||
            (!StationReadPermissions.Contains(requiredReadPermission) &&
             !GlobalReadPermissions.Contains(requiredReadPermission)))
            return MetraAuthorizationDecision.Deny(MetraAuthorizationOutcome.DeniedPermissionMissing);

        var grants = actor.Grants ?? Array.Empty<MetraAuthorizationGrant>();
        var matchingPermissionGrants = grants.Where(grant =>
            grant is not null && grant.IsActive &&
            grant.Permissions is not null && grant.Permissions.Contains(requiredReadPermission));

        foreach (var grant in matchingPermissionGrants)
        {
            if (string.Equals(grant.ScopeType, "station", StringComparison.Ordinal) &&
                grant.StationId == requestedStationId &&
                StationReadPermissions.Contains(requiredReadPermission))
                return MetraAuthorizationDecision.Allow(MetraAuthorizationOutcome.AllowedStationScope);

            if (string.Equals(grant.ScopeType, "global", StringComparison.Ordinal) &&
                grant.StationId is null && grant.OrganizationId is null &&
                grant.RoleCode is not null && GlobalReadRoles.Contains(grant.RoleCode) &&
                GlobalReadPermissions.Contains(requiredReadPermission))
                return MetraAuthorizationDecision.Allow(MetraAuthorizationOutcome.AllowedGlobalRead);
        }

        var hasAnyPermission = matchingPermissionGrants.Any();
        return MetraAuthorizationDecision.Deny(hasAnyPermission
            ? MetraAuthorizationOutcome.DeniedScopeMismatch
            : MetraAuthorizationOutcome.DeniedPermissionMissing);
    }

    private static bool IsCanonicalPermission(string value) =>
        value.Length is > 2 and <= 96 &&
        value == value.Trim() &&
        value.All(character => char.IsAsciiLetterOrDigit(character) || character is '.' or '_' or '-');
}