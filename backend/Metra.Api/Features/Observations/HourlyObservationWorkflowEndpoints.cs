using Microsoft.AspNetCore.Mvc;

namespace Metra.Api.Features.Observations;

/// <summary>
/// HTTP adapters for the authenticated hourly submission/review workflow.
/// Map this extension only after trusted actor-context and durable store
/// implementations have been registered in dependency injection.
/// </summary>
public static class HourlyObservationWorkflowEndpoints
{
    public static IEndpointRouteBuilder MapHourlyObservationWorkflowEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/v1/observations/hourly")
            .WithTags("Hourly observations")
            .RequireAuthorization();

        group.MapPost("/", async (
            [FromBody] CreateHourlyObservationRequest? request,
            HourlyObservationApplicationService service,
            CancellationToken cancellationToken) =>
        {
            var result = await service.SubmitAsync(request, cancellationToken);
            if (result.Succeeded && result.Value is not null)
            {
                return Results.Created(
                    $"/api/v1/observations/hourly/{Uri.EscapeDataString(result.Value.ObservationId)}",
                    result.Value);
            }

            return ToHttpResult(result.Code, result.Message, result.Issues);
        }).WithName("SubmitHourlyObservation");

        group.MapPost("/{observationId}/review", async (
            string observationId,
            [FromBody] HourlyObservationReviewRequest? request,
            HourlyObservationApplicationService service,
            CancellationToken cancellationToken) =>
        {
            var result = await service.ReviewAsync(observationId, request, cancellationToken);
            return result.Succeeded && result.Value is not null
                ? Results.Ok(result.Value)
                : ToHttpResult(result.Code, result.Message);
        }).WithName("ReviewHourlyObservation");

        return endpoints;
    }

    private static IResult ToHttpResult(string code, string message, IReadOnlyList<Metra.Api.Domain.Observations.ValidationIssue>? resultIssues = null)
        => code switch
        {
            "unauthenticated" => Results.Problem(
                title: "Authentication required",
                detail: message,
                statusCode: StatusCodes.Status401Unauthorized),
            "permission_denied" or "station_scope_violation" or "self_review_forbidden"
                => Results.Problem(
                    title: "Access denied",
                    detail: message,
                    statusCode: StatusCodes.Status403Forbidden),
            "not_found" => Results.Problem(
                title: "Observation not found",
                detail: message,
                statusCode: StatusCodes.Status404NotFound),
            "invalid_state" or "review_conflict" => Results.Problem(
                title: "Observation state conflict",
                detail: message,
                statusCode: StatusCodes.Status409Conflict),
            "observation_validation_failed" when resultIssues is not null
                => Results.ValidationProblem(resultIssues
                    .GroupBy(issue => issue.Field, StringComparer.Ordinal)
                    .ToDictionary(
                        group => group.Key,
                        group => group.Select(issue => issue.Message).Distinct(StringComparer.Ordinal).ToArray(),
                        StringComparer.Ordinal)),
            "invalid_observation_id" or "invalid_request" or "invalid_review"
                or "station_context_required" or "observation_validation_failed"
                => Results.ValidationProblem(
                    new Dictionary<string, string[]> { ["request"] = [message] }),
            _ => Results.Problem(
                title: "Observation workflow unavailable",
                detail: "تعذر إتمام العملية حالياً.",
                statusCode: StatusCodes.Status500InternalServerError)
        };
}
