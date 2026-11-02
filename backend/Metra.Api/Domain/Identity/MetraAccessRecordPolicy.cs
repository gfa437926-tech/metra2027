namespace Metra.Api.Domain.Identity;

public sealed record MetraAccessRecordValidationResult(bool IsValid, string Code);

/// <summary>
/// Validates persisted temporal grant and assignment records before they can
/// enter the authoritative access store. This does not authorize the actor
/// performing the mutation.
/// </summary>
public static class MetraAccessRecordPolicy
{
    public static MetraAccessRecordValidationResult ValidateGrant(MetraPermissionGrant? grant)
    {
        if (grant is null)
            return Invalid("permission_grant_required");

        if (!IsCanonicalCode(grant.PermissionCode))
            return Invalid("permission_code_invalid");

        if (grant.StationId is not null && !IsValidStationId(grant.StationId))
            return Invalid("station_scope_invalid");

        if (grant.ValidFromUtc.Offset != TimeSpan.Zero ||
            grant.ValidUntilUtc is { } end && end.Offset != TimeSpan.Zero ||
            grant.RevokedAtUtc is { } revoked && revoked.Offset != TimeSpan.Zero)
            return Invalid("access_record_time_must_be_utc");

        if (grant.ValidUntilUtc is { } until && until <= grant.ValidFromUtc)
            return Invalid("access_record_window_invalid");

        if (grant.RevokedAtUtc is { } revokedAt &&
            (revokedAt < grant.ValidFromUtc ||
             grant.ValidUntilUtc is { } validUntil && revokedAt >= validUntil))
            return Invalid("access_record_revocation_time_invalid");

        return new(true, "access_record_valid");
    }

    public static MetraAccessRecordValidationResult ValidateAssignment(MetraStationAssignment? assignment)
    {
        if (assignment is null)
            return Invalid("station_assignment_required");

        if (!IsValidStationId(assignment.StationId))
            return Invalid("station_scope_invalid");

        if (assignment.ValidFromUtc.Offset != TimeSpan.Zero ||
            assignment.ValidUntilUtc is { } end && end.Offset != TimeSpan.Zero ||
            assignment.RevokedAtUtc is { } revoked && revoked.Offset != TimeSpan.Zero)
            return Invalid("access_record_time_must_be_utc");

        if (assignment.ValidUntilUtc is { } until && until <= assignment.ValidFromUtc)
            return Invalid("access_record_window_invalid");

        if (assignment.RevokedAtUtc is { } revokedAt &&
            (revokedAt < assignment.ValidFromUtc ||
             assignment.ValidUntilUtc is { } validUntil && revokedAt >= validUntil))
            return Invalid("access_record_revocation_time_invalid");

        return new(true, "access_record_valid");
    }

    private static bool IsValidStationId(string? stationId)
        => !string.IsNullOrWhiteSpace(stationId) &&
           stationId.Length <= 128 &&
           stationId == stationId.Trim() &&
           stationId.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_' or '.');

    private static bool IsCanonicalCode(string? code)
    {
        if (string.IsNullOrEmpty(code) || code.Length > 128)
            return false;

        var hasCharacter = false;
        foreach (var character in code)
        {
            if (character is >= 'a' and <= 'z' or >= '0' and <= '9')
            {
                hasCharacter = true;
                continue;
            }

            if (character is '.' or '_' or '-')
            {
                if (!hasCharacter)
                    return false;
                hasCharacter = false;
                continue;
            }

            return false;
        }

        return hasCharacter;
    }

    private static MetraAccessRecordValidationResult Invalid(string code)
        => new(false, code);
}
