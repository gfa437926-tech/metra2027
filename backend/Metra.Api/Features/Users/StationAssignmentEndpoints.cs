using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Users;

public sealed record StationAssignmentRequest(
    Guid? UserId, string? RoleCode, string? Reason,
    DateTimeOffset? ValidFrom, DateTimeOffset? ValidTo);

public sealed record StationAssignmentDecisionRequest(string? Decision, string? Note);
public sealed record StationAssignmentRevocationRequest(string? Reason);
public sealed record StationAssignmentOutcome(bool IsConfigured, bool Succeeded, HttpStatusCode? StatusCode, JsonElement? Data);

public interface IStationAssignmentService
{
    bool IsConfigured { get; }
    Task<JsonElement?> GetAssignableRolesAsync(CancellationToken cancellationToken);
    Task<StationAssignmentOutcome> RequestAsync(
        Guid stationId, Guid actorUserId, StationAssignmentRequest request, CancellationToken cancellationToken);
    Task<StationAssignmentOutcome> DecideAsync(
        Guid stationId, Guid assignmentId, Guid actorUserId,
        StationAssignmentDecisionRequest request, CancellationToken cancellationToken);
    Task<StationAssignmentOutcome> RevokeAsync(
        Guid stationId, Guid assignmentId, Guid actorUserId,
        StationAssignmentRevocationRequest request, CancellationToken cancellationToken);
}

public sealed class SupabaseStationAssignmentService(
    IHttpClientFactory clients, IConfiguration configuration) : IStationAssignmentService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public async Task<JsonElement?> GetAssignableRolesAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;
        using var message = CreateRequest(
            HttpMethod.Get,
            "/rest/v1/metra_role_catalogue?select=role_code,name_ar,name_en&role_code=in.(observer,station_auditor)&is_active=eq.true&order=role_code.asc");
        return await SendForJsonAsync(message, cancellationToken);
    }

    public async Task<StationAssignmentOutcome> RequestAsync(
        Guid stationId, Guid actorUserId, StationAssignmentRequest request, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return new(false, false, null, null);
        using var message = CreateRequest(HttpMethod.Post, "/rest/v1/rpc/request_station_assignment");
        message.Content = JsonContent.Create(new
        {
            p_user_id = request.UserId,
            p_station_id = stationId,
            p_role_code = request.RoleCode,
            p_actor_user_id = actorUserId,
            p_reason = request.Reason,
            p_valid_from = request.ValidFrom,
            p_valid_to = request.ValidTo
        });
        return await SendOutcomeAsync(message, cancellationToken);
    }

    public async Task<StationAssignmentOutcome> DecideAsync(
        Guid stationId, Guid assignmentId, Guid actorUserId,
        StationAssignmentDecisionRequest request, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return new(false, false, null, null);
        using var message = CreateRequest(HttpMethod.Post, "/rest/v1/rpc/decide_station_assignment");
        message.Content = JsonContent.Create(new
        {
            p_assignment_id = assignmentId,
            p_station_id = stationId,
            p_expected_status = "pending",
            p_actor_user_id = actorUserId,
            p_decision = request.Decision,
            p_note = request.Note,
            p_occurred_at = DateTimeOffset.UtcNow
        });
        return await SendOutcomeAsync(message, cancellationToken);
    }


    public async Task<StationAssignmentOutcome> RevokeAsync(
        Guid stationId, Guid assignmentId, Guid actorUserId,
        StationAssignmentRevocationRequest request, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return new(false, false, null, null);
        using var message = CreateRequest(HttpMethod.Post, "/rest/v1/rpc/revoke_station_assignment");
        message.Content = JsonContent.Create(new
        {
            p_assignment_id = assignmentId,
            p_station_id = stationId,
            p_actor_user_id = actorUserId,
            p_reason = request.Reason,
            p_occurred_at = DateTimeOffset.UtcNow
        });
        return await SendOutcomeAsync(message, cancellationToken);
    }

    private HttpRequestMessage CreateRequest(HttpMethod method, string path)
    {
        var message = new HttpRequestMessage(method, $"{_url!.TrimEnd('/')}{path}");
        message.Headers.TryAddWithoutValidation("apikey", _key);
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
        return message;
    }

    private async Task<JsonElement?> SendForJsonAsync(HttpRequestMessage message, CancellationToken cancellationToken)
    {
        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseStationAssignmentService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode) return null;
            return await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: cancellationToken);
        }
        catch (HttpRequestException) { return null; }
        catch (JsonException) { return null; }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested) { return null; }
    }

    private async Task<StationAssignmentOutcome> SendOutcomeAsync(
        HttpRequestMessage message, CancellationToken cancellationToken)
    {
        var data = await SendForJsonAsync(message, cancellationToken);
        return data is null
            ? new(true, false, HttpStatusCode.ServiceUnavailable, null)
            : new(true, true, HttpStatusCode.OK, data);
    }
}

public static class StationAssignmentRequestGuard
{
    public static string? GetError(StationAssignmentRequest? request, Guid actorUserId)
    {
        if (request is null || request.UserId is null || request.UserId == Guid.Empty ||
            request.UserId == actorUserId)
            return "invalid_assignment_target";
        if (request.RoleCode is not ("observer" or "station_auditor"))
            return "station_role_not_assignable";
        if (string.IsNullOrWhiteSpace(request.Reason) || request.Reason != request.Reason.Trim() ||
            request.Reason.Length is < 5 or > 2000 || request.Reason.Any(char.IsControl))
            return "invalid_assignment_reason";
        if (request.ValidFrom is null ||
            (request.ValidTo is not null && request.ValidTo <= request.ValidFrom))
            return "invalid_assignment_validity";
        return null;
    }
}

public static class StationAssignmentDecisionRequestGuard
{
    public static string? GetError(StationAssignmentDecisionRequest? request)
    {
        if (request is null || request.Decision is not ("approve" or "reject"))
            return "invalid_assignment_decision";
        if (request.Note is { Length: > 2000 } ||
            request.Note?.Any(char.IsControl) == true ||
            (request.Note is not null && request.Note != request.Note.Trim()))
            return "invalid_assignment_note";
        if (request.Decision == "reject" && string.IsNullOrWhiteSpace(request.Note))
            return "assignment_rejection_reason_required";
        return null;
    }
}


public static class StationAssignmentRevocationRequestGuard
{
    public static string? GetError(StationAssignmentRevocationRequest? request)
    {
        if (request is null || string.IsNullOrWhiteSpace(request.Reason) ||
            request.Reason != request.Reason.Trim() ||
            request.Reason.Length is < 5 or > 2000 ||
            request.Reason.Any(char.IsControl))
            return "invalid_assignment_revocation_reason";
        return null;
    }
}

public static class StationAssignmentEndpoints
{
    public static IEndpointRouteBuilder MapStationAssignmentEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/stations/{stationId:guid}/assignable-roles", async (
            Guid stationId, IStationAssignmentService service, CancellationToken cancellationToken) =>
        {
            if (!service.IsConfigured)
                return Results.Problem(title: "Station assignment service unavailable", statusCode: 503);
            var roles = await service.GetAssignableRolesAsync(cancellationToken);
            return roles is null
                ? Results.Problem(title: "Assignable roles unavailable", statusCode: 503)
                : Results.Ok(roles.Value);
        })
        .RequireStationPermission("users.station.manage")
        .WithTags("Users")
        .RequireRateLimiting(MetraRateLimiting.PolicyRead)
            .WithName("GetStationAssignableRoles");

        endpoints.MapPost("/api/v1/stations/{stationId:guid}/assignments", async (
            Guid stationId, StationAssignmentRequest? request, HttpContext http,
            IStationAssignmentService service, CancellationToken cancellationToken) =>
        {
            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorUserId))
                return Results.Unauthorized();
            var error = StationAssignmentRequestGuard.GetError(request, actorUserId);
            if (error is not null) return Results.BadRequest(new { error });
            if (!service.IsConfigured)
                return Results.Problem(title: "Station assignment service unavailable", statusCode: 503);

            var outcome = await service.RequestAsync(stationId, actorUserId, request!, cancellationToken);
            if (!outcome.Succeeded)
                return Results.Problem(title: "Station assignment request unavailable", statusCode: 503);
            var result = RegistrationSubmissionRpcResult.GetStatus(outcome.Data);
            if (result == "created") return Results.Created($"/api/v1/stations/{stationId}/users", outcome.Data);
            if (result == "unauthorized") return Results.Forbid();
            if (result == "conflict") return Results.Conflict(new { error = result });
            if (result is "station_not_available" or "target_account_not_active" or
                "target_authority_membership_required" or "assignment_role_unavailable")
                return Results.BadRequest(new { error = result });
            return Results.Problem(title: "Unexpected assignment request response", statusCode: 503);
        })
        .RequireStationPermission("users.station.manage")
        .WithTags("Users")
        .RequireRateLimiting(MetraRateLimiting.PolicySensitive)
            .WithName("RequestStationAssignment");

        endpoints.MapPost("/api/v1/stations/{stationId:guid}/assignments/{assignmentId:guid}/decision", async (
            Guid stationId, Guid assignmentId, StationAssignmentDecisionRequest? request, HttpContext http,
            IStationAssignmentService service, CancellationToken cancellationToken) =>
        {
            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorUserId))
                return Results.Unauthorized();
            var error = StationAssignmentDecisionRequestGuard.GetError(request);
            if (error is not null) return Results.BadRequest(new { error });
            if (!service.IsConfigured)
                return Results.Problem(title: "Station assignment service unavailable", statusCode: 503);

            var outcome = await service.DecideAsync(stationId, assignmentId, actorUserId, request!, cancellationToken);
            if (!outcome.Succeeded)
                return Results.Problem(title: "Station assignment decision unavailable", statusCode: 503);
            var result = RegistrationDecisionRpcResult.GetStatus(outcome.Data);
            if (result == "committed") return Results.Ok(outcome.Data);
            if (result == "unauthorized") return Results.Forbid();
            if (result == "not_found") return Results.NotFound();
            if (result == "conflict") return Results.Conflict(new { error = result });
            return Results.Problem(title: "Unexpected assignment decision response", statusCode: 503);
        })
        .RequireStationPermission("users.station.manage")
        .WithTags("Users")
        .RequireRateLimiting(MetraRateLimiting.PolicySensitive)
            .WithName("DecideStationAssignment");


        endpoints.MapPost("/api/v1/stations/{stationId:guid}/assignments/{assignmentId:guid}/revoke", async (
            Guid stationId, Guid assignmentId, StationAssignmentRevocationRequest? request, HttpContext http,
            IStationAssignmentService service, CancellationToken cancellationToken) =>
        {
            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorUserId))
                return Results.Unauthorized();
            var error = StationAssignmentRevocationRequestGuard.GetError(request);
            if (error is not null) return Results.BadRequest(new { error });
            if (!service.IsConfigured)
                return Results.Problem(title: "Station assignment service unavailable", statusCode: 503);

            var outcome = await service.RevokeAsync(stationId, assignmentId, actorUserId, request!, cancellationToken);
            if (!outcome.Succeeded)
                return Results.Problem(title: "Station assignment revocation unavailable", statusCode: 503);
            var result = RegistrationDecisionRpcResult.GetStatus(outcome.Data);
            if (result == "committed") return Results.Ok(outcome.Data);
            if (result == "unauthorized") return Results.Forbid();
            if (result == "not_found") return Results.NotFound();
            if (result == "conflict") return Results.Conflict(new { error = result });
            return Results.Problem(title: "Unexpected assignment revocation response", statusCode: 503);
        })
        .RequireStationPermission("users.station.manage")
        .WithTags("Users")
        .RequireRateLimiting(MetraRateLimiting.PolicySensitive)
            .WithName("RevokeStationAssignment");

        return endpoints;
    }
}
