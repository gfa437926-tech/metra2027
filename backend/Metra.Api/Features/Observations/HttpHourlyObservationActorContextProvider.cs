using System.Security.Claims;
using Metra.Api.Features.Identity;

namespace Metra.Api.Features.Observations;

/// <summary>
/// Builds observation authorization context from the validated HTTP principal
/// and the same authoritative METRA identity snapshot used by /identity/me.
/// No user, station, role, or permission identifier is accepted from request data.
/// </summary>
public sealed class HttpHourlyObservationActorContextProvider(
    IHttpContextAccessor httpContextAccessor,
    CurrentUserContextApplicationService currentUserContextService)
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

        var context = await currentUserContextService.GetAsync(
            issuer, subject, cancellationToken);
        if (context is null ||
            !string.Equals(context.AccountState, MetraAccountState.Active.ToString(), StringComparison.Ordinal))
            return null;

        var grants = context.Assignments
            .Where(assignment => assignment.IsActive)
            .Select(assignment => new HourlyObservationStationGrant(
                assignment.StationId,
                assignment.ValidFrom,
                assignment.ValidTo,
                null))
            .ToArray();

        return new HourlyObservationActorContext(
            context.UserId,
            true,
            Array.AsReadOnly(grants),
            new HashSet<string>(context.Permissions, StringComparer.Ordinal));
    }
}
