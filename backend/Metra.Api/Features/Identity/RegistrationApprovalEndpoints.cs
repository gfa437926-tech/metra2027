using Metra.Api.Domain.Identity;

namespace Metra.Api.Features.Identity;

public sealed record RegistrationApprovalDecisionHttpRequest(
    RegistrationApprovalDecision Decision,
    string? Note);

public static class RegistrationApprovalEndpoints
{
    public static IEndpointRouteBuilder MapRegistrationApprovalEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
            "/api/v1/registration-requests/approval-queue",
            async (
                string? status,
                string? stationId,
                int? pageSize,
                string? cursor,
                RegistrationApprovalQueueQueryService service,
                CancellationToken cancellationToken) =>
            {
                RegistrationApprovalStatus? parsedStatus = null;
                if (status is not null)
                {
                    if (!Enum.TryParse<RegistrationApprovalStatus>(status, true, out var parsed) ||
                        !Enum.IsDefined(parsed))
                        return Results.BadRequest(new { code = "invalid_query" });
                    parsedStatus = parsed;
                }

                var result = await service.ReadAsync(
                    new RegistrationApprovalQueueQuery(parsedStatus, stationId, pageSize ?? 50, cursor),
                    cancellationToken);

                return result.Status switch
                {
                    RegistrationApprovalQueueReadStatus.Succeeded => Results.Ok(result.Page),
                    RegistrationApprovalQueueReadStatus.Unauthenticated => Results.Unauthorized(),
                    RegistrationApprovalQueueReadStatus.Unauthorized => Results.Forbid(),
                    RegistrationApprovalQueueReadStatus.InvalidQuery => Results.BadRequest(new { code = "invalid_query" }),
                    _ => Results.Problem(statusCode: 500, title: "تعذر قراءة قائمة طلبات الاعتماد.")
                };
            })
            .RequireAuthorization()
            .WithName("GetRegistrationApprovalQueue")
            .WithTags("Identity");

        endpoints.MapPost(
            "/api/v1/registration-requests/{requestId}/decision",
            async (
                string requestId,
                RegistrationApprovalDecisionHttpRequest? request,
                RegistrationApprovalApplicationService service,
                CancellationToken cancellationToken) =>
            {
                if (request is null)
                    return Results.BadRequest(new { code = "invalid_request" });

                var result = await service.DecideAsync(
                    new SubmitRegistrationApprovalDecision(requestId, request.Decision, request.Note),
                    cancellationToken);

                if (result.Succeeded)
                    return Results.Ok(result);

                var status = result.Code switch
                {
                    "unauthenticated" => StatusCodes.Status401Unauthorized,
                    "registration_request_not_found" => StatusCodes.Status404NotFound,
                    "invalid_request" or "invalid_decision" or "note_too_long" or "note_invalid" or "note_required"
                        => StatusCodes.Status400BadRequest,
                    "inactive_actor" or "self_approval_forbidden" or
                    "station_approval_permission_required" or "station_scope_violation" or
                    "station_approval_evidence_missing" or
                    "approval_separation_of_duties_violation" or
                    "system_approval_permission_required" => StatusCodes.Status403Forbidden,
                    _ => StatusCodes.Status409Conflict
                };

                return Results.Problem(statusCode: status, title: result.Message,
                    extensions: new Dictionary<string, object?> { ["code"] = result.Code });
            })
            .RequireAuthorization()
            .WithName("DecideRegistrationApproval")
            .WithTags("Identity");

        return endpoints;
    }
}
