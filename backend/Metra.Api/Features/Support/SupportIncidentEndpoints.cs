using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Domain.Support;
using Metra.Api.Security;

namespace Metra.Api.Features.Support;

public sealed record SupportIncidentSubmitRequest(
    string? Kind,
    string? Category,
    string? Title,
    string? Description,
    string? AffectedAsset,
    string? Severity,
    DateTimeOffset? OccurredAt,
    bool ImpactsOperations = false);

public sealed record SupportIncidentTransitionRequest(
    string? ToStatus,
    string? Note,
    Guid? AssignedTo);

public sealed record SupportIncidentServiceOutcome(
    bool IsConfigured,
    bool Succeeded,
    HttpStatusCode? StatusCode,
    JsonElement? Data);

public interface ISupportIncidentService
{
    bool IsConfigured { get; }
    Task<SupportIncidentServiceOutcome> SubmitAsync(
        Guid userId, Guid stationId, SupportIncidentSubmitRequest request, CancellationToken cancellationToken);
    Task<SupportIncidentServiceOutcome> ListAsync(
        Guid stationId, int limit, CancellationToken cancellationToken);
    Task<SupportIncidentServiceOutcome> GetByIdAsync(
        Guid stationId, Guid incidentId, CancellationToken cancellationToken);
    Task<SupportIncidentServiceOutcome> TransitionAsync(
        Guid userId, Guid stationId, Guid incidentId, SupportIncidentTransitionRequest request, CancellationToken cancellationToken);
}

public static class SupportIncidentRequestGuard
{
    public static IReadOnlyList<Metra.Api.Domain.Observations.ValidationIssue> ValidateSubmit(
        Guid stationId, Guid userId, SupportIncidentSubmitRequest? request, DateTimeOffset now)
    {
        if (request is null)
            return [new("body", "طلب بلاغ الدعم مطلوب.")];
        if (!Enum.TryParse<SupportIncidentKind>(request.Kind, true, out var kind) || !Enum.IsDefined(kind))
            return [new(nameof(request.Kind), "نوع البلاغ غير معروف.")];
        if (!Enum.TryParse<SupportIncidentSeverity>(request.Severity, true, out var severity) || !Enum.IsDefined(severity))
            return [new(nameof(request.Severity), "درجة الأولوية غير معروفة.")];

        var report = new SupportIncidentReport(
            stationId,
            userId,
            kind,
            request.Category ?? string.Empty,
            request.Title ?? string.Empty,
            request.Description ?? string.Empty,
            request.AffectedAsset,
            severity,
            request.OccurredAt ?? default,
            request.ImpactsOperations);
        return SupportIncidentPolicy.Validate(report, now);
    }

    public static bool TryParseStatus(string? value, out SupportIncidentStatus status)
        => Enum.TryParse(value, true, out status) && Enum.IsDefined(status);

    public static string PermissionForTransition(SupportIncidentStatus toStatus) => toStatus switch
    {
        // Review / reject decisions
        SupportIncidentStatus.UnderReview or SupportIncidentStatus.Rejected => "support_incident.review",
        // Assignment to support staff
        SupportIncidentStatus.Assigned => "support_incident.assign",
        // Active work and information requests — not resolve/close
        SupportIncidentStatus.InProgress or SupportIncidentStatus.WaitingForInformation
            => "support_incident.update",
        // Final resolve and close
        SupportIncidentStatus.Resolved or SupportIncidentStatus.Closed => "support_incident.resolve",
        _ => "support_incident.review"
    };
}

public sealed class SupabaseSupportIncidentService(
    IHttpClientFactory clients,
    IConfiguration configuration) : ISupportIncidentService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public Task<SupportIncidentServiceOutcome> SubmitAsync(
        Guid userId, Guid stationId, SupportIncidentSubmitRequest request, CancellationToken cancellationToken)
        => RpcAsync("metra_submit_support_incident", new
        {
            p_user_id = userId,
            p_station_id = stationId,
            p_kind = request.Kind,
            p_category = request.Category,
            p_title = request.Title,
            p_description = request.Description,
            p_affected_asset = request.AffectedAsset,
            p_severity = request.Severity,
            p_occurred_at = request.OccurredAt,
            p_impacts_operations = request.ImpactsOperations
        }, cancellationToken);

    public async Task<SupportIncidentServiceOutcome> ListAsync(
        Guid stationId, int limit, CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || limit is < 1 or > 100)
            return new(IsConfigured, false, null, null);

        var query =
            $"station_id=eq.{stationId:D}" +
            "&select=id,station_id,reporter_user_id,kind,category,title,description,affected_asset,severity,status,impacts_operations,occurred_at,assigned_to,created_at,updated_at" +
            "&order=occurred_at.desc&limit=" + limit;
        using var message = new HttpRequestMessage(
            HttpMethod.Get, $"{_url!.TrimEnd('/')}/rest/v1/metra_support_incidents?{query}");
        ApplyAuth(message);
        return await SendAsync(message, cancellationToken);
    }

    
    public async Task<SupportIncidentServiceOutcome> GetByIdAsync(
        Guid stationId, Guid incidentId, CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || incidentId == Guid.Empty)
            return new(IsConfigured, false, null, null);

        var query =
            $"id=eq.{incidentId:D}&station_id=eq.{stationId:D}" +
            "&select=id,station_id,reporter_user_id,kind,category,title,description,affected_asset,severity,status,impacts_operations,occurred_at,assigned_to,created_at,updated_at" +
            "&limit=1";
        using var message = new HttpRequestMessage(
            HttpMethod.Get,
            $"{_url!.TrimEnd('/')}/rest/v1/metra_support_incidents?{query}");
        ApplyAuth(message);
        var outcome = await SendAsync(message, cancellationToken);
        if (!outcome.Succeeded || outcome.Data is null)
            return outcome;
        if (outcome.Data.Value.ValueKind == JsonValueKind.Array)
        {
            if (outcome.Data.Value.GetArrayLength() == 0)
                return new(true, false, HttpStatusCode.NotFound, null);
            return new(true, true, HttpStatusCode.OK, outcome.Data.Value[0].Clone());
        }
        return outcome;
    }

    public Task<SupportIncidentServiceOutcome> TransitionAsync(
        Guid userId, Guid stationId, Guid incidentId, SupportIncidentTransitionRequest request, CancellationToken cancellationToken)
        => RpcAsync("metra_transition_support_incident", new
        {
            p_user_id = userId,
            p_station_id = stationId,
            p_incident_id = incidentId,
            p_to_status = request.ToStatus,
            p_note = request.Note,
            p_assigned_to = request.AssignedTo
        }, cancellationToken);

    private async Task<SupportIncidentServiceOutcome> RpcAsync(
        string rpc, object body, CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new(false, false, null, null);
        using var message = new HttpRequestMessage(
            HttpMethod.Post, $"{_url!.TrimEnd('/')}/rest/v1/rpc/{rpc}");
        ApplyAuth(message);
        message.Content = JsonContent.Create(body);
        return await SendAsync(message, cancellationToken);
    }

    private void ApplyAuth(HttpRequestMessage message)
    {
        message.Headers.TryAddWithoutValidation("apikey", _key);
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
    }

    private async Task<SupportIncidentServiceOutcome> SendAsync(
        HttpRequestMessage message, CancellationToken cancellationToken)
    {
        try
        {
            using var response = await clients
                .CreateClient(nameof(SupabaseSupportIncidentService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(cancellationToken);
                return new(true, false, MapFailure(body, response.StatusCode), null);
            }
            var data = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: cancellationToken);
            return new(true, true, response.StatusCode, data);
        }
        catch (HttpRequestException)
        {
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
        catch (JsonException)
        {
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
    }

    public static HttpStatusCode MapFailure(string? body, HttpStatusCode fallback)
    {
        if (string.IsNullOrWhiteSpace(body))
            return fallback is >= HttpStatusCode.BadRequest and < HttpStatusCode.InternalServerError
                ? fallback : HttpStatusCode.ServiceUnavailable;
        if (body.Contains("station_support_incident_create_forbidden", StringComparison.Ordinal) ||
            body.Contains("station_support_incident_transition_forbidden", StringComparison.Ordinal))
            return HttpStatusCode.Forbidden;
        if (body.Contains("support_incident_not_found", StringComparison.Ordinal))
            return HttpStatusCode.NotFound;
        if (body.Contains("invalid_support_state_transition", StringComparison.Ordinal))
            return HttpStatusCode.Conflict;
        if (body.Contains("invalid_support", StringComparison.Ordinal))
            return HttpStatusCode.BadRequest;
        return fallback is >= HttpStatusCode.BadRequest and < HttpStatusCode.InternalServerError
            ? fallback : HttpStatusCode.ServiceUnavailable;
    }
}

public static class SupportIncidentEndpoints
{
    public static IEndpointRouteBuilder MapSupportIncidentEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost("/api/v1/stations/{stationId:guid}/support-incidents",
            async (Guid stationId, SupportIncidentSubmitRequest? request, HttpContext http,
                ISupportIncidentService service, CancellationToken ct) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId) || userId == Guid.Empty)
                    return Results.Unauthorized();
                var issues = SupportIncidentRequestGuard.ValidateSubmit(stationId, userId, request, DateTimeOffset.UtcNow);
                if (issues.Count > 0)
                    return Results.BadRequest(new { error = "validation_failed", issues });
                if (!service.IsConfigured)
                    return Results.Problem(title: "Support incident service unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                var result = await service.SubmitAsync(userId, stationId, request!, ct);
                if (!result.Succeeded)
                {
                    if (result.StatusCode == HttpStatusCode.Forbidden) return Results.Forbid();
                    return Results.Problem(title: "Support incident persistence unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }
                return Results.Json(result.Data, statusCode: StatusCodes.Status201Created);
            })
            .RequireStationPermission("support_incident.create")
            .WithTags("Support").WithName("SubmitSupportIncident");

        endpoints.MapGet("/api/v1/stations/{stationId:guid}/support-incidents",
            async (Guid stationId, int? limit, ISupportIncidentService service, CancellationToken ct) =>
            {
                var take = limit ?? 50;
                if (take is < 1 or > 100)
                    return Results.BadRequest(new { error = "invalid_limit", maximum = 100 });
                if (!service.IsConfigured)
                    return Results.Problem(title: "Support incident service unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                var result = await service.ListAsync(stationId, take, ct);
                if (!result.Succeeded || result.Data is null)
                    return Results.Problem(title: "Support incident list unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                return Results.Ok(result.Data);
            })
            .RequireStationPermission("support_incident.read")
            .WithTags("Support").WithName("ListSupportIncidents");

        
        endpoints.MapGet("/api/v1/stations/{stationId:guid}/support-incidents/{incidentId:guid}",
            async (Guid stationId, Guid incidentId, ISupportIncidentService service, CancellationToken cancellationToken) =>
            {
                if (!service.IsConfigured)
                    return Results.Problem(title: "Support incident service unavailable", statusCode: StatusCodes.Status503ServiceUnavailable);
                var result = await service.GetByIdAsync(stationId, incidentId, cancellationToken);
                if (!result.Succeeded || result.Data is null)
                {
                    if (result.StatusCode == HttpStatusCode.NotFound)
                        return Results.NotFound(new { error = "support_incident_not_found" });
                    return Results.Problem(title: "Support incident detail unavailable", statusCode: StatusCodes.Status503ServiceUnavailable);
                }
                // Defense in depth: require station_id and reject cross-station leakage.
                if (!result.Data.Value.TryGetProperty("station_id", out var stationProp)
                    || !Guid.TryParse(stationProp.GetString(), out var rowStation)
                    || rowStation != stationId)
                {
                    return Results.NotFound(new { error = "support_incident_not_found" });
                }
                return Results.Ok(result.Data);
            })
            .RequireStationPermission("support_incident.read")
            .WithTags("Support")
            .WithName("GetSupportIncidentById");

endpoints.MapPost("/api/v1/stations/{stationId:guid}/support-incidents/{incidentId:guid}/transitions",
            async (Guid stationId, Guid incidentId, SupportIncidentTransitionRequest? request, HttpContext http,
                ISupportIncidentService service, IStationAuthorizationService authorization, CancellationToken ct) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId) || userId == Guid.Empty)
                    return Results.Unauthorized();
                if (request is null || !SupportIncidentRequestGuard.TryParseStatus(request.ToStatus, out var toStatus))
                    return Results.BadRequest(new { error = "invalid_support_transition" });
                if ((toStatus is SupportIncidentStatus.Rejected or SupportIncidentStatus.Closed) &&
                    string.IsNullOrWhiteSpace(request.Note))
                    return Results.BadRequest(new { error = "transition_note_required" });

                var permission = SupportIncidentRequestGuard.PermissionForTransition(toStatus);
                if (!await authorization.HasStationPermissionAsync(userId, stationId, permission, ct))
                    return Results.Forbid();
                if (!service.IsConfigured)
                    return Results.Problem(title: "Support incident service unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var result = await service.TransitionAsync(userId, stationId, incidentId, request, ct);
                if (!result.Succeeded)
                {
                    if (result.StatusCode == HttpStatusCode.Forbidden) return Results.Forbid();
                    if (result.StatusCode == HttpStatusCode.NotFound)
                        return Results.NotFound(new { error = "support_incident_not_found" });
                    if (result.StatusCode == HttpStatusCode.Conflict)
                        return Results.Conflict(new { error = "invalid_support_state_transition" });
                    return Results.Problem(title: "Support incident transition unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }
                return Results.Ok(result.Data);
            })
            .RequireStationPermission("support_incident.read")
            .WithTags("Support").WithName("TransitionSupportIncident");

        return endpoints;
    }
}
