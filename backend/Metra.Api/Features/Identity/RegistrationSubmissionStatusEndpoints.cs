using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace Metra.Api.Features.Identity;

public static class RegistrationSubmissionStatusEndpoints
{
    public static IEndpointRouteBuilder MapRegistrationSubmissionStatusEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
                "/api/v1/registration-requests/{requestId:guid}",
                async (
                    Guid requestId,
                    RegistrationSubmissionStatusApplicationService service,
                    CancellationToken cancellationToken) =>
                {
                    var result = await service.ReadOwnAsync(requestId, cancellationToken);
                    if (!result.Succeeded)
                    {
                        return result.Code switch
                        {
                            "invalid_request_id" => Results.BadRequest(new { code = result.Code }),
                            "unauthenticated" => Results.Unauthorized(),
                            // Do not disclose whether another applicant's request exists.
                            "registration_request_not_found" => Results.NotFound(new { code = result.Code }),
                            _ => Results.Problem(
                                statusCode: StatusCodes.Status500InternalServerError,
                                title: result.Message,
                                extensions: new Dictionary<string, object?> { ["code"] = result.Code })
                        };
                    }

                    return Results.Ok(result.Value);
                })
            .RequireAuthorization()
            .WithName("GetOwnRegistrationRequestStatus")
            .WithTags("Identity")
            .Produces<RegistrationSubmissionStatusResponse>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status404NotFound);

        return endpoints;
    }
}
