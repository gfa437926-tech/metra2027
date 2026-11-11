using Metra.Api.Domain.Observations;
using Microsoft.AspNetCore.Mvc;

namespace Metra.Api.Features.Observations;

public static class ObservationValidationEndpoints
{
    public static IEndpointRouteBuilder MapObservationValidationEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/v1/observations").WithTags("Observation validation");

        group.MapPost("/daily/validate", ([FromBody] ObservationValidationRequest? request) =>
        {
            var error = ObservationValidationRequestGuard.GetError(request?.Values);
            if (error is not null) return Results.BadRequest(new { error });
            if (!ObservationFieldContract.IsDailyReportType(request!.ReportType))
                return Results.BadRequest(new { error = "invalid_daily_report_type" });
            if (!request.ResponsibilityAgreement)
                return Results.BadRequest(new { error = "responsibility_agreement_required" });
            var issues = DailyObservationValidator.Validate(
                request.Values!, ObservationFieldContract.GetDailyRequiredFields(request.ReportType));
            return Results.Ok(new ValidationResponse(issues.Count == 0, issues));
        }).WithName("ValidateDailyObservation");

        group.MapPost("/hourly/validate", ([FromBody] ObservationValidationRequest? request) =>
        {
            var error = ObservationValidationRequestGuard.GetError(request?.Values);
            if (error is not null) return Results.BadRequest(new { error });
            var issues = HourlyObservationValidator.Validate(request!.Values!);
            return Results.Ok(new ValidationResponse(issues.Count == 0, issues));
        }).WithName("ValidateHourlyObservation");

        group.MapPost("/phenomena/validate", ([FromBody] WeatherPhenomenonRequest? request) =>
        {
            var issues = WeatherPhenomenonValidator.Validate(request);
            return Results.Ok(new ValidationResponse(issues.Count == 0, issues));
        }).WithName("ValidateWeatherPhenomenon");

        return endpoints;
    }
}

public sealed record ObservationValidationRequest(
    Dictionary<string, string?>? Values,
    string? ReportType = null,
    bool ResponsibilityAgreement = false);
public sealed record ValidationResponse(bool IsValid, IReadOnlyList<ValidationIssue> Issues);