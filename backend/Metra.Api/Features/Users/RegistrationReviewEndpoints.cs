using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Users;

public sealed record RegistrationDecisionRequest(string? Decision, string? Note);
public sealed record RegistrationDecisionOutcome(bool IsConfigured, bool Succeeded, HttpStatusCode? StatusCode, JsonElement? Data);

public interface IRegistrationReviewService
{
    bool IsConfigured { get; }
    Task<JsonElement?> GetPendingForStationAsync(Guid stationId, string expectedStatus, int limit, CancellationToken cancellationToken);
    Task<JsonElement?> GetAuditForStationAsync(Guid stationId, int limit, CancellationToken cancellationToken);
    Task<RegistrationDecisionOutcome> DecideAsync(Guid stationId, string expectedStatus, Guid requestId, Guid actorUserId, RegistrationDecisionRequest request, CancellationToken cancellationToken);
}

public sealed class SupabaseRegistrationReviewService(IHttpClientFactory clients, IConfiguration configuration) : IRegistrationReviewService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public async Task<JsonElement?> GetPendingForStationAsync(Guid stationId, string expectedStatus, int limit, CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || limit is < 1 or > 100 ||
            expectedStatus is not ("pending_station_approval" or "pending_system_approval")) return null;

        // Deliberately omit email/auth fields. Return only the minimum profile,
        // request, station and role data needed for the station approval decision.
        var query = "select=id,user_id,requested_station_id,requested_role_code,status,phone_snapshot,terms_version,submitted_at,metra_user_profiles(first_name,father_name,last_name),metra_role_catalogue(name_ar,name_en),station_catalogue(name_ar,name_en,local_station_code)" +
            "&requested_station_id=eq." + stationId.ToString("D") +
            "&status=eq." + expectedStatus + "&order=submitted_at.asc&limit=" + limit;
        using var message = new HttpRequestMessage(HttpMethod.Get, $"{_url!.TrimEnd('/')}/rest/v1/registration_requests?{query}");
        message.Headers.TryAddWithoutValidation("apikey", _key);
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseRegistrationReviewService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode) return null;
            return await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: cancellationToken);
        }
        catch (HttpRequestException) { return null; }
        catch (JsonException) { return null; }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested) { return null; }
    }


    public async Task<JsonElement?> GetAuditForStationAsync(Guid stationId, int limit, CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || limit is < 1 or > 200) return null;
        var query = "select=id,request_id,user_id,actor_user_id,event_type,terms_version,decision_note,occurred_at,registration_requests!inner(requested_station_id)" +
            "&registration_requests.requested_station_id=eq." + stationId.ToString("D") +
            "&order=occurred_at.desc&limit=" + limit;
        using var message = new HttpRequestMessage(HttpMethod.Get, $"{_url!.TrimEnd('/')}/rest/v1/registration_audit_events?{query}");
        message.Headers.TryAddWithoutValidation("apikey", _key);
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseRegistrationReviewService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode) return null;
            return await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: cancellationToken);
        }
        catch (HttpRequestException) { return null; }
        catch (JsonException) { return null; }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested) { return null; }
    }

    public async Task<RegistrationDecisionOutcome> DecideAsync(
        Guid stationId, string expectedStatus, Guid requestId, Guid actorUserId, RegistrationDecisionRequest request, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return new(false, false, null, null);
        using var message = new HttpRequestMessage(HttpMethod.Post, $"{_url!.TrimEnd('/')}/rest/v1/rpc/decide_metra_registration_for_station");
        message.Headers.TryAddWithoutValidation("apikey", _key);
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
        message.Content = JsonContent.Create(new
        {
            p_request_id = requestId,
            p_station_id = stationId,
            p_expected_status = expectedStatus,
            p_actor_user_id = actorUserId,
            p_decision = request.Decision,
            p_note = request.Note,
            p_occurred_at = DateTimeOffset.UtcNow
        });
        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseRegistrationReviewService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode) return new(true, false, response.StatusCode, null);
            var data = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: cancellationToken);
            return new(true, true, response.StatusCode, data);
        }
        catch (HttpRequestException) { return new(true, false, HttpStatusCode.ServiceUnavailable, null); }
        catch (JsonException) { return new(true, false, HttpStatusCode.ServiceUnavailable, null); }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        { return new(true, false, HttpStatusCode.ServiceUnavailable, null); }
    }
}

public static class RegistrationDecisionRequestGuard
{
    public static string? GetError(RegistrationDecisionRequest? request)
    {
        if (request is null || request.Decision is not ("approve" or "reject"))
            return "invalid_registration_decision";
        if (request.Note is { Length: > 2000 }) return "registration_note_too_long";
        if (request.Decision == "reject" &&
            (string.IsNullOrWhiteSpace(request.Note) || request.Note != request.Note.Trim()))
            return "registration_rejection_reason_required";
        if (request.Note?.Any(char.IsControl) == true) return "registration_note_contains_control_characters";
        return null;
    }
}

public static class RegistrationReviewEndpoints
{
    public static IEndpointRouteBuilder MapRegistrationReviewEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/stations/{stationId:guid}/registration-requests", async (
            Guid stationId, int? limit, IRegistrationReviewService review, CancellationToken cancellationToken) =>
        {
            var take = limit ?? 50;
            if (take is < 1 or > 100)
                return Results.BadRequest(new { error = "invalid_limit", maximum = 100 });
            if (!review.IsConfigured)
                return Results.Problem(title: "Registration review unavailable", statusCode: 503);
            var result = await review.GetPendingForStationAsync(stationId, "pending_station_approval", take, cancellationToken);
            return result is null
                ? Results.Problem(title: "Registration queue read failed", statusCode: 503)
                : Results.Ok(result.Value);
        })
        .RequireStationPermission("registrations.station.approve")
        .WithTags("Users")
        .WithName("GetStationRegistrationRequests");

        endpoints.MapPost("/api/v1/stations/{stationId:guid}/registration-requests/{requestId:guid}/decision", async (
            Guid stationId, Guid requestId, RegistrationDecisionRequest? request, HttpContext http,
            IRegistrationReviewService review, CancellationToken cancellationToken) =>
        {
            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorUserId))
                return Results.Unauthorized();
            var error = RegistrationDecisionRequestGuard.GetError(request);
            if (error is not null) return Results.BadRequest(new { error });
            if (!review.IsConfigured)
                return Results.Problem(title: "Registration review unavailable", statusCode: 503);

            // The request must belong to the station in the route. The RPC independently
            // locks the request, checks its stage, prevents self-review, and validates
            // the actor's approved station assignment and individual permission grant.
            var outcome = await review.DecideAsync(stationId, "pending_station_approval", requestId, actorUserId, request!, cancellationToken);
            if (!outcome.Succeeded)
            {
                if (outcome.StatusCode == HttpStatusCode.Forbidden) return Results.Forbid();
                if (outcome.StatusCode == HttpStatusCode.NotFound) return Results.NotFound();
                if (outcome.StatusCode == HttpStatusCode.Conflict)
                    return Results.Conflict(new { error = "registration_state_conflict" });
                if (outcome.StatusCode == HttpStatusCode.BadRequest)
                    return Results.BadRequest(new { error = "registration_decision_rejected" });
                return Results.Problem(title: "Registration decision persistence unavailable", statusCode: 503);
            }

            // PostgREST can return HTTP 200 while the transactional RPC reports a domain denial.
            var rpcStatus = RegistrationDecisionRpcResult.GetStatus(outcome.Data);
            if (rpcStatus == "unauthorized") return Results.Forbid();
            if (rpcStatus == "not_found") return Results.NotFound();
            if (rpcStatus == "conflict") return Results.Conflict(new { error = "registration_state_conflict" });
            if (rpcStatus != "committed")
                return Results.Problem(title: "Unexpected registration decision response", statusCode: 503);

            return Results.Ok(outcome.Data);
        })
        .RequireStationPermission("registrations.station.approve")
        .WithTags("Users")
        .WithName("DecideStationRegistrationRequest");


        endpoints.MapGet("/api/v1/stations/{stationId:guid}/system-registration-requests", async (
            Guid stationId, int? limit, IRegistrationReviewService review, CancellationToken cancellationToken) =>
        {
            var take = limit ?? 50;
            if (take is < 1 or > 100)
                return Results.BadRequest(new { error = "invalid_limit", maximum = 100 });
            if (!review.IsConfigured)
                return Results.Problem(title: "System registration review unavailable", statusCode: 503);
            var result = await review.GetPendingForStationAsync(stationId, "pending_system_approval", take, cancellationToken);
            return result is null
                ? Results.Problem(title: "System registration queue read failed", statusCode: 503)
                : Results.Ok(result.Value);
        })
        .RequireStationPermission("registrations.system.approve")
        .WithTags("Users")
        .WithName("GetSystemRegistrationRequests");

        endpoints.MapPost("/api/v1/stations/{stationId:guid}/system-registration-requests/{requestId:guid}/decision", async (
            Guid stationId, Guid requestId, RegistrationDecisionRequest? request, HttpContext http,
            IRegistrationReviewService review, CancellationToken cancellationToken) =>
        {
            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorUserId))
                return Results.Unauthorized();
            var error = RegistrationDecisionRequestGuard.GetError(request);
            if (error is not null) return Results.BadRequest(new { error });
            if (!review.IsConfigured)
                return Results.Problem(title: "System registration review unavailable", statusCode: 503);

            var outcome = await review.DecideAsync(
                stationId, "pending_system_approval", requestId, actorUserId, request!, cancellationToken);
            if (!outcome.Succeeded)
            {
                if (outcome.StatusCode == HttpStatusCode.Forbidden) return Results.Forbid();
                if (outcome.StatusCode == HttpStatusCode.NotFound) return Results.NotFound();
                if (outcome.StatusCode == HttpStatusCode.Conflict)
                    return Results.Conflict(new { error = "registration_state_conflict" });
                if (outcome.StatusCode == HttpStatusCode.BadRequest)
                    return Results.BadRequest(new { error = "registration_decision_rejected" });
                return Results.Problem(title: "System registration decision unavailable", statusCode: 503);
            }

            var rpcStatus = RegistrationDecisionRpcResult.GetStatus(outcome.Data);
            if (rpcStatus == "unauthorized") return Results.Forbid();
            if (rpcStatus == "not_found") return Results.NotFound();
            if (rpcStatus == "conflict") return Results.Conflict(new { error = "registration_state_conflict" });
            if (rpcStatus != "committed")
                return Results.Problem(title: "Unexpected system registration decision response", statusCode: 503);

            return Results.Ok(outcome.Data);
        })
        .RequireStationPermission("registrations.system.approve")
        .WithTags("Users")
        .WithName("DecideSystemRegistrationRequest");


        endpoints.MapGet("/api/v1/stations/{stationId:guid}/registration-audit", async (
            Guid stationId, int? limit, IRegistrationReviewService review, CancellationToken cancellationToken) =>
        {
            var take = limit ?? 100;
            if (take is < 1 or > 200)
                return Results.BadRequest(new { error = "invalid_limit", maximum = 200 });
            if (!review.IsConfigured)
                return Results.Problem(title: "Registration audit unavailable", statusCode: 503);
            var result = await review.GetAuditForStationAsync(stationId, take, cancellationToken);
            return result is null
                ? Results.Problem(title: "Registration audit read failed", statusCode: 503)
                : Results.Ok(result.Value);
        })
        .RequireStationPermission("registrations.station.approve")
        .WithTags("Users")
        .WithName("GetStationRegistrationAudit");

        endpoints.MapGet("/api/v1/stations/{stationId:guid}/system-registration-audit", async (
            Guid stationId, int? limit, IRegistrationReviewService review, CancellationToken cancellationToken) =>
        {
            var take = limit ?? 100;
            if (take is < 1 or > 200)
                return Results.BadRequest(new { error = "invalid_limit", maximum = 200 });
            if (!review.IsConfigured)
                return Results.Problem(title: "Registration audit unavailable", statusCode: 503);
            var result = await review.GetAuditForStationAsync(stationId, take, cancellationToken);
            return result is null
                ? Results.Problem(title: "Registration audit read failed", statusCode: 503)
                : Results.Ok(result.Value);
        })
        .RequireStationPermission("registrations.system.approve")
        .WithTags("Users")
        .WithName("GetSystemRegistrationAudit");

        return endpoints;
    }
}

public static class RegistrationDecisionRpcResult
{
    public static string? GetStatus(JsonElement? data)
    {
        if (data is null) return null;
        var value = data.Value;
        if (value.ValueKind == JsonValueKind.Array)
        {
            if (value.GetArrayLength() == 0) return null;
            value = value[0];
        }
        if (value.ValueKind != JsonValueKind.Object ||
            !value.TryGetProperty("result_status", out var status) ||
            status.ValueKind != JsonValueKind.String)
            return null;
        return status.GetString();
    }
}
