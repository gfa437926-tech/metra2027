using System.Security.Claims;
using Microsoft.AspNetCore.Http;

namespace Metra.Api.Features.Identity;

/// <summary>
/// Builds the initial-registration actor exclusively from the validated
/// authentication principal. The Supabase JWT sub must be a UUID; no request
/// field, header, user metadata or fallback display claim is consulted.
/// </summary>
public sealed class HttpRegistrationSubmissionActorContextProvider(
    IHttpContextAccessor httpContextAccessor)
    : IRegistrationSubmissionActorContextProvider
{
    public Task<RegistrationSubmissionActorContext?> GetCurrentAsync(
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var principal = httpContextAccessor.HttpContext?.User;
        if (principal?.Identity?.IsAuthenticated != true)
        {
            return Task.FromResult<RegistrationSubmissionActorContext?>(null);
        }

        var subject = principal.FindFirst("sub")?.Value;
        if (!Guid.TryParse(subject, out var authUserId) || authUserId == Guid.Empty)
        {
            return Task.FromResult<RegistrationSubmissionActorContext?>(null);
        }

        return Task.FromResult<RegistrationSubmissionActorContext?>(
            new RegistrationSubmissionActorContext(authUserId, IsAuthenticated: true));
    }
}
