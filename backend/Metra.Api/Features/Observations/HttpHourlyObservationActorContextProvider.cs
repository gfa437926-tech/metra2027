using System.Security.Claims;
using Metra.Api.Features.Identity;

namespace Metra.Api.Features.Observations;

/// <summary>
/// Resolves the current actor from the validated HTTP principal and the
/// authoritative METRA identity data source. Request bodies cannot supply
/// user IDs, station assignments, account state, or permissions.
/// </summary>
public sealed class HttpHourlyObservationActorContextProvider(
    IHttpContextAccessor httpContextAccessor,
    ICurrentUserContextDataSource identityDataSource,
    TimeProvider timeProvider)
    : IHourlyObservationActorContextProvider
{
    public async Task<HourlyObservationActorContext?> GetCurrentActorAsync(
        CancellationToken cancellationToken)
    {
        var principal = httpContextAccessor.HttpContext?.User;
        if (principal?.Identity?.IsAuthenticated != true)
            return null;

        var issuer = principal.FindFirst("iss")?.Value;
        var subject = principal.FindFirst("sub")?.Value
            ?? principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrWhiteSpace(issuer) || string.IsNullOrWhiteSpace(subject))
            return null;

        var facts = await identityDataSource.FindByIdentitySubjectAsync(
            issuer, subject, cancellationToken);
        if (facts is null ||
            facts.AccountState != MetraAccountState.Active ||
            !IsCanonicalIdentifier(facts.UserId) ||
            facts.Assignments is null ||
            facts.PermissionGrants is null ||
            facts.Assignments.Any(x => x is null ||
                !IsCanonicalIdentifier(x.StationId) ||
                !IsCanonicalCode(x.RoleCode) ||
                !IsValidUtcWindow(x.ValidFrom, x.ValidTo, x.RevokedAt)) ||
            facts.PermissionGrants.Any(x => x is null ||
                !IsCanonicalCode(x.Permission) ||
                !IsValidUtcWindow(x.ValidFrom, x.ValidTo, x.RevokedAt)))
            return null;

        var now = timeProvider.GetUtcNow();
        var grants = facts.Assignments
            .Where(x => x is not null &&
                x.ValidFrom.Offset == TimeSpan.Zero &&
                x.ValidFrom <= now &&
                (x.ValidTo is null || x.ValidTo.Value.Offset == TimeSpan.Zero && now < x.ValidTo.Value) &&
                (x.RevokedAt is null || x.RevokedAt.Value.Offset == TimeSpan.Zero && now < x.RevokedAt.Value))
            .Select(x => new HourlyObservationStationGrant(
                x.StationId, x.ValidFrom, x.ValidTo, x.RevokedAt))
            .ToArray();

        var permissions = facts.PermissionGrants
            .Where(x => x is not null &&
                x.ValidFrom.Offset == TimeSpan.Zero &&
                x.ValidFrom <= now &&
                (x.ValidTo is null || x.ValidTo.Value.Offset == TimeSpan.Zero && now < x.ValidTo.Value) &&
                (x.RevokedAt is null || x.RevokedAt.Value.Offset == TimeSpan.Zero && now < x.RevokedAt.Value))
            .Select(x => x.Permission)
            .Where(x => x is HourlyObservationApplicationService.SubmitPermission
                or HourlyObservationApplicationService.ReviewPermission)
            .ToHashSet(StringComparer.Ordinal);

        return new HourlyObservationActorContext(
            facts.UserId,
            true,
            Array.AsReadOnly(grants),
            permissions);
    }

    private static bool IsCanonicalIdentifier(string? value)
        => !string.IsNullOrWhiteSpace(value) &&
           value.Length <= 128 &&
           value == value.Trim() &&
           value.All(character => char.IsAsciiLetterOrDigit(character) ||
               character is '-' or '_' or '.' or ':');

    private static bool IsCanonicalCode(string? value)
        => !string.IsNullOrEmpty(value) &&
           value.Length <= 128 &&
           value == value.Trim() &&
           value.All(character => character is >= 'a' and <= 'z' or >= '0' and <= '9'
               or '.' or '_' or '-');

    private static bool IsValidUtcWindow(
        DateTimeOffset validFrom,
        DateTimeOffset? validTo,
        DateTimeOffset? revokedAt)
        => validFrom.Offset == TimeSpan.Zero &&
           (validTo is null || validTo.Value.Offset == TimeSpan.Zero && validTo.Value > validFrom) &&
           (revokedAt is null || revokedAt.Value.Offset == TimeSpan.Zero);
}
