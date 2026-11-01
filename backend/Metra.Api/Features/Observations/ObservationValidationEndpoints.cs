using Metra.Api.Domain.Observations;
using Microsoft.AspNetCore.Mvc;

namespace Metra.Api.Features.Observations;

public static class ObservationValidationEndpoints
{
    public static IEndpointRouteBuilder MapObservationValidationEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/v1/observations").WithTags("Observation validation");

        group.MapPost("/daily/validate", ([FromBody] ObservationValidationRequest request) =>
        {
            var issues = DailyObservationValidator.Validate(request.Values);
            return Results.Ok(new ValidationResponse(issues.Count == 0, issues));
        }).WithName("ValidateDailyObservation");

        group.MapPost("/hourly/validate", ([FromBody] ObservationValidationRequest request) =>
        {
            var issues = HourlyObservationValidator.Validate(request.Values);
            return Results.Ok(new ValidationResponse(issues.Count == 0, issues));
        }).WithName("ValidateHourlyObservation");

        return endpoints;
    }
}

public sealed record ObservationValidationRequest(Dictionary<string, string?> Values);
public sealed record ValidationResponse(bool IsValid, IReadOnlyList<ValidationIssue> Issues);