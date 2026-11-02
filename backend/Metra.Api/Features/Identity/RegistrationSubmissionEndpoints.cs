using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace Metra.Api.Features.Identity;

/// <summary>
/// HTTP adapter for initial registration. Deliberately not mapped in Program.cs
/// until trusted actor, catalogue and atomic store adapters are registered.
/// </summary>
public static class RegistrationSubmissionEndpoints
{
    public static IEndpointRouteBuilder MapRegistrationSubmissionEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost(
                "/api/v1/registration-requests",
                async (
                    SubmitRegistrationRequest? request,
                    RegistrationSubmissionApplicationService service,
                    CancellationToken cancellationToken) =>
                {
                    var result = await service.SubmitAsync(request, cancellationToken);
                    if (!result.Succeeded)
                    {
                        var status = result.Code switch
                        {
                            "invalid_registration" or "terms_not_accepted" => StatusCodes.Status400BadRequest,
                            "unauthenticated" => StatusCodes.Status401Unauthorized,
                            "role_not_available" or "station_not_available" => StatusCodes.Status422UnprocessableEntity,
                            "auth_user_already_linked" or "registration_already_pending" or
                                "registration_submission_conflict" => StatusCodes.Status409Conflict,
                            _ => StatusCodes.Status500InternalServerError
                        };

                        return Results.Problem(
                            statusCode: status,
                            title: result.Message,
                            extensions: new Dictionary<string, object?>
                            {
                                ["code"] = result.Code
                            });
                    }

                    var response = new RegistrationSubmissionHttpResponse(
                        result.Code,
                        result.Message,
                        result.AccountId!.Value,
                        result.RequestId!.Value,
                        "PendingStationApproval");

                    return Results.Json(
                        response,
                        statusCode: result.Code == "registration_already_submitted"
                            ? StatusCodes.Status200OK
                            : StatusCodes.Status201Created);
                })
            .RequireAuthorization()
            .RequireRateLimiting("RegistrationSubmission")
            .WithName("SubmitRegistrationRequest")
            .WithTags("Identity")
            .Produces<RegistrationSubmissionHttpResponse>(StatusCodes.Status201Created)
            .Produces<RegistrationSubmissionHttpResponse>(StatusCodes.Status200OK)
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status401Unauthorized)
            .ProducesProblem(StatusCodes.Status409Conflict)
            .ProducesProblem(StatusCodes.Status422UnprocessableEntity)
            .ProducesProblem(StatusCodes.Status500InternalServerError);

        return endpoints;
    }
}

public sealed record RegistrationSubmissionHttpResponse(
    string Code,
    string Message,
    Guid AccountId,
    Guid RequestId,
    string Status);
