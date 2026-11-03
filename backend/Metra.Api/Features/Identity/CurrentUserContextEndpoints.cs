using System.Security.Claims;

namespace Metra.Api.Features.Identity;

/// <summary>
/// Returns only the current authenticated subject's METRA context. The subject
/// and issuer are read from the validated server principal, never from input.
/// </summary>
public static class CurrentUserContextEndpoints
{
    public static IEndpointRouteBuilder MapCurrentUserContextEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
                "/api/v1/identity/me",
                async (
                    HttpContext httpContext,
                    CurrentUserContextApplicationService service,
                    CancellationToken cancellationToken) =>
                {
                    var issuer = httpContext.User.FindFirst("iss")?.Value;
                    var subject = httpContext.User.FindFirst("sub")?.Value
                        ?? httpContext.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                    if (string.IsNullOrWhiteSpace(issuer) || string.IsNullOrWhiteSpace(subject))
                        return Results.Unauthorized();

                    var response = await service.GetAsync(issuer, subject, cancellationToken);
                    return response is null
                        ? Results.NotFound()
                        : Results.Ok(response);
                })
            .RequireAuthorization()
            .WithName("GetCurrentMetraUserContext")
            .WithTags("Identity")
            .Produces<CurrentUserContextResponse>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status404NotFound);

        return endpoints;
    }
}
