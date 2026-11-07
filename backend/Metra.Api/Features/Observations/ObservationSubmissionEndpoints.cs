using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Observations;

public sealed record ObservationSubmissionRequest(
    string? IdempotencyKey,
    string? ObservationType,
    DateTimeOffset? ObservedAt,
    JsonElement? Payload,
    bool Submit = false);

public sealed record ObservationSubmissionOutcome(
    bool IsConfigured,
    bool Succeeded,
    HttpStatusCode? StatusCode,
    JsonElement? Data);

public interface IObservationSubmissionService
{
    bool IsConfigured { get; }
    Task<ObservationSubmissionOutcome> SubmitAsync(
        Guid userId, Guid stationId, ObservationSubmissionRequest request,
        CancellationToken cancellationToken);
}

/// <summary>
/// Calls the database's atomic, idempotent observation submission RPC.
/// The service-role credential remains exclusively on the server.
/// </summary>
public sealed class SupabaseObservationSubmissionService(
    IHttpClientFactory clients,
    IConfiguration configuration) : IObservationSubmissionService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _serviceKey = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_serviceKey);

    public async Task<ObservationSubmissionOutcome> SubmitAsync(
        Guid userId, Guid stationId, ObservationSubmissionRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new(false, false, null, null);

        var client = clients.CreateClient(nameof(SupabaseObservationSubmissionService));
        using var message = new HttpRequestMessage(
            HttpMethod.Post, $"{_url!.TrimEnd('/')}/rest/v1/rpc/metra_submit_observation");
        message.Headers.TryAddWithoutValidation("apikey", _serviceKey);
        message.Headers.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _serviceKey);
        message.Content = JsonContent.Create(new
        {
            p_user_id = userId,
            p_station_id = stationId,
            p_idempotency_key = request.IdempotencyKey,
            p_observation_type = request.ObservationType,
            p_observed_at = request.ObservedAt,
            p_payload = request.Payload,
            p_submit = request.Submit
        });

        try
        {
            using var response = await client.SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return new(true, false, response.StatusCode, null);

            var data = await response.Content.ReadFromJsonAsync<JsonElement>(
                cancellationToken: cancellationToken);
            return new(true, true, response.StatusCode, data);
        }
        catch (JsonException)
        {
            // A malformed success body is not a successful persistence result.
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
        catch (HttpRequestException)
        {
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
    }
}

public static class ObservationSubmissionEndpoints
{
    public static IEndpointRouteBuilder MapObservationSubmissionEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost(
            "/api/v1/stations/{stationId:guid}/observations",
            async (
                Guid stationId,
                ObservationSubmissionRequest? request,
                HttpContext http,
                IObservationSubmissionService submission,
                CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId))
                    return Results.Unauthorized();

                var validationError = ObservationSubmissionRequestGuard.GetError(request);
                if (validationError is not null)
                    return Results.BadRequest(new { error = validationError });

                if (!submission.IsConfigured)
                    return Results.Problem(
                        title: "Observation service unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var result = await submission.SubmitAsync(
                    userId, stationId, request!, cancellationToken);

                if (!result.Succeeded)
                {
                    if (result.StatusCode == HttpStatusCode.Forbidden)
                        return Results.Forbid();
                    if (result.StatusCode == HttpStatusCode.Conflict)
                        return Results.Conflict(new { error = "idempotency_conflict" });
                    if (result.StatusCode == HttpStatusCode.BadRequest)
                        return Results.BadRequest(new { error = "invalid_observation_request" });

                    return Results.Problem(
                        title: "Observation persistence unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }

                return Results.Ok(result.Data);
            })
            .RequireStationPermission("observation.create")
            .WithTags("Observations")
            .WithName("SubmitStationObservation");

        return endpoints;
    }
}

public static class ObservationSubmissionRequestGuard
{
    public static string? GetError(ObservationSubmissionRequest? request)
    {
        if (request is null ||
            string.IsNullOrWhiteSpace(request.IdempotencyKey) ||
            request.IdempotencyKey.Length > 128 ||
            request.IdempotencyKey != request.IdempotencyKey.Trim())
            return "invalid_idempotency_key";

        if (request.ObservationType is not ("daily" or "hourly" or "phenomenon"))
            return "invalid_observation_type";

        if (request.ObservedAt is null ||
            request.Payload is null ||
            request.Payload.Value.ValueKind != JsonValueKind.Object ||
            request.Payload.Value.GetRawText().Length > 65536)
            return "invalid_observation_payload";

        return null;
    }
}

public sealed record ObservationDecisionRequest(string? Decision, string? Note);

public sealed record ObservationDecisionOutcome(
    bool IsConfigured,
    bool Succeeded,
    HttpStatusCode? StatusCode,
    JsonElement? Data);

public sealed record ObservationOwnership(
    Guid ObservationId,
    Guid StationId,
    Guid CreatedByUserId,
    string Status);

public interface IObservationDecisionService
{
    bool IsConfigured { get; }

    /// <summary>
    /// Loads observation ownership only within the requested station scope.
    /// Returns null when the observation is missing, mis-scoped, or the read fails closed.
    /// </summary>
    Task<ObservationOwnership?> GetOwnershipAsync(
        Guid stationId,
        Guid observationId,
        CancellationToken cancellationToken);

    Task<ObservationDecisionOutcome> DecideAsync(
        Guid userId,
        Guid stationId,
        Guid observationId,
        ObservationDecisionRequest request,
        CancellationToken cancellationToken);
}

public sealed class SupabaseObservationDecisionService(
    IHttpClientFactory clients,
    IConfiguration configuration) : IObservationDecisionService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public async Task<ObservationOwnership?> GetOwnershipAsync(
        Guid stationId,
        Guid observationId,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || observationId == Guid.Empty)
            return null;

        // Station scope is enforced in the query so a cross-station id cannot leak ownership.
        var query =
            $"id=eq.{observationId:D}&station_id=eq.{stationId:D}" +
            "&select=id,station_id,created_by,status&limit=1";
        using var message = new HttpRequestMessage(
            HttpMethod.Get,
            $"{_url!.TrimEnd('/')}/rest/v1/metra_observations?{query}");
        message.Headers.TryAddWithoutValidation("apikey", _key);
        message.Headers.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _key);

        try
        {
            using var response = await clients
                .CreateClient(nameof(SupabaseObservationDecisionService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return null;

            var payload = await response.Content.ReadFromJsonAsync<JsonElement>(
                cancellationToken: cancellationToken);
            if (payload.ValueKind != JsonValueKind.Array || payload.GetArrayLength() != 1)
                return null;

            var row = payload[0];
            if (!row.TryGetProperty("id", out var idEl) ||
                !row.TryGetProperty("station_id", out var stationEl) ||
                !row.TryGetProperty("created_by", out var createdEl) ||
                !row.TryGetProperty("status", out var statusEl) ||
                !Guid.TryParse(idEl.GetString(), out var id) ||
                !Guid.TryParse(stationEl.GetString(), out var scopedStationId) ||
                !Guid.TryParse(createdEl.GetString(), out var createdBy) ||
                statusEl.GetString() is not { Length: > 0 } status ||
                scopedStationId != stationId ||
                id != observationId)
            {
                return null;
            }

            return new ObservationOwnership(id, scopedStationId, createdBy, status);
        }
        catch (JsonException)
        {
            return null;
        }
        catch (HttpRequestException)
        {
            return null;
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return null;
        }
    }

    public async Task<ObservationDecisionOutcome> DecideAsync(
        Guid userId,
        Guid stationId,
        Guid observationId,
        ObservationDecisionRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new(false, false, null, null);

        using var message = new HttpRequestMessage(
            HttpMethod.Post,
            $"{_url!.TrimEnd('/')}/rest/v1/rpc/metra_decide_observation");
        message.Headers.TryAddWithoutValidation("apikey", _key);
        message.Headers.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _key);
        message.Content = JsonContent.Create(new
        {
            p_user_id = userId,
            p_station_id = stationId,
            p_observation_id = observationId,
            p_decision = request.Decision,
            p_note = request.Note
        });

        try
        {
            using var response = await clients
                .CreateClient(nameof(SupabaseObservationDecisionService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync(cancellationToken);
                var mapped = MapDecisionFailure(errorBody, response.StatusCode);
                return new(true, false, mapped, null);
            }

            var data = await response.Content.ReadFromJsonAsync<JsonElement>(
                cancellationToken: cancellationToken);
            return new(true, true, response.StatusCode, data);
        }
        catch (JsonException)
        {
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
        catch (HttpRequestException)
        {
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
    }

    /// <summary>
    /// Maps database decision failures to stable HTTP outcomes. The database RPC is
    /// authoritative for ownership, station scope, status, and separation of duties.
    /// </summary>
    public static HttpStatusCode MapDecisionFailure(string? errorBody, HttpStatusCode fallback)
    {
        if (string.IsNullOrWhiteSpace(errorBody))
            return fallback is HttpStatusCode.Forbidden or HttpStatusCode.NotFound or HttpStatusCode.Conflict
                ? fallback
                : HttpStatusCode.ServiceUnavailable;

        if (errorBody.Contains("self_review_forbidden", StringComparison.Ordinal))
            return HttpStatusCode.Conflict;
        if (errorBody.Contains("observation_not_found", StringComparison.Ordinal))
            return HttpStatusCode.NotFound;
        if (errorBody.Contains("observation_not_in_submitted_state", StringComparison.Ordinal))
            return HttpStatusCode.Conflict;
        if (errorBody.Contains("station_observation_decision_forbidden", StringComparison.Ordinal) ||
            errorBody.Contains("42501", StringComparison.Ordinal))
            return HttpStatusCode.Forbidden;
        if (errorBody.Contains("invalid_observation_decision", StringComparison.Ordinal) ||
            errorBody.Contains("decision_note_required", StringComparison.Ordinal) ||
            errorBody.Contains("decision_note_too_long", StringComparison.Ordinal))
            return HttpStatusCode.BadRequest;

        return fallback is >= HttpStatusCode.BadRequest and < HttpStatusCode.InternalServerError
            ? fallback
            : HttpStatusCode.ServiceUnavailable;
    }
}

public static class ObservationDecisionEndpoints
{
    public static IEndpointRouteBuilder MapObservationDecisionEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost(
            "/api/v1/stations/{stationId:guid}/observations/{observationId:guid}/decision",
            async (
                Guid stationId,
                Guid observationId,
                ObservationDecisionRequest? request,
                HttpContext http,
                IObservationDecisionService service,
                IStationAuthorizationService authorization,
                CancellationToken ct) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId))
                    return Results.Unauthorized();

                var validationError = ObservationDecisionRequestGuard.GetError(request);
                if (validationError is not null)
                    return Results.BadRequest(new { error = validationError });

                // Fail closed: missing authorization configuration never becomes allow.
                if (!authorization.IsConfigured)
                    return Results.Problem(
                        title: "Authorization service unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                if (!service.IsConfigured)
                    return Results.Problem(
                        title: "Observation service unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var requiredPermission = request!.Decision == "approve"
                    ? "observation.approve"
                    : "observation.return_for_correction";
                var requiredDomainPermission = request.Decision == "approve"
                    ? Metra.Api.Domain.Observations.ObservationPermission.Approve
                    : Metra.Api.Domain.Observations.ObservationPermission.ReturnForCorrection;

                var allowed = await authorization.HasStationPermissionAsync(
                    userId, stationId, requiredPermission, ct);
                if (!allowed)
                    return Results.Forbid();

                // Load ownership inside the station scope before any decision write.
                var ownership = await service.GetOwnershipAsync(stationId, observationId, ct);
                if (ownership is null)
                    return Results.NotFound(new { error = "observation_not_found" });

                var policy = Metra.Api.Domain.Observations.ObservationAuthorizationPolicy.Authorize(
                    new Metra.Api.Domain.Observations.ObservationActorContext(
                        userId.ToString(),
                        stationId.ToString(),
                        HasActiveStationAssignment: true,
                        Permissions: new HashSet<Metra.Api.Domain.Observations.ObservationPermission>
                        {
                            requiredDomainPermission
                        }),
                    new Metra.Api.Domain.Observations.ObservationResourceContext(
                        ownership.StationId.ToString(),
                        ownership.CreatedByUserId.ToString()),
                    requiredDomainPermission);

                if (!policy.IsAuthorized)
                {
                    if (policy.ErrorCode == "self_review_forbidden")
                        return Results.Conflict(new { error = "self_review_forbidden" });
                    if (policy.ErrorCode == "station_scope_violation")
                        return Results.Forbid();
                    return Results.Forbid();
                }

                var result = await service.DecideAsync(
                    userId, stationId, observationId, request, ct);
                if (!result.Succeeded)
                {
                    if (result.StatusCode == HttpStatusCode.Forbidden)
                        return Results.Forbid();
                    if (result.StatusCode == HttpStatusCode.NotFound)
                        return Results.NotFound(new { error = "observation_not_found" });
                    if (result.StatusCode == HttpStatusCode.BadRequest)
                        return Results.BadRequest(new { error = "invalid_observation_decision" });
                    if (result.StatusCode == HttpStatusCode.Conflict)
                        return Results.Conflict(new { error = "observation_decision_rejected" });
                    return Results.Problem(
                        title: "Observation decision unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }

                return Results.Ok(result.Data);
            })
            .WithTags("Observations")
            .WithName("DecideStationObservation");

        return endpoints;
    }
}

public static class ObservationDecisionRequestGuard
{
    public static string? GetError(ObservationDecisionRequest? request)
    {
        if (request is null || request.Decision is not ("approve" or "return_for_correction"))
            return "invalid_observation_decision";
        if (request.Note is { Length: > 2000 })
            return "decision_note_too_long";
        if (request.Decision == "return_for_correction" &&
            string.IsNullOrWhiteSpace(request.Note))
            return "decision_note_required";
        if (request.Note is not null && request.Note != request.Note.Trim())
            return "invalid_decision_note";
        return null;
    }
}
