using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Domain.Maintenance;
using Metra.Api.Domain.Observations;
using Metra.Api.Security;

namespace Metra.Api.Features.Maintenance;

public sealed record EquipmentFaultSubmitRequest(
    string? EquipmentCategory,
    string? EquipmentName,
    string? Description,
    string? Severity,
    DateTimeOffset? OccurredAt,
    bool IsOperationallyBlocking = false);

public sealed record EquipmentFaultTransitionRequest(
    string? ToStatus,
    string? Note,
    int? ProgressPercent,
    Guid? AssignedTo);

public sealed record EquipmentFaultServiceOutcome(
    bool IsConfigured,
    bool Succeeded,
    HttpStatusCode? StatusCode,
    JsonElement? Data,
    IReadOnlyList<ValidationIssue>? ValidationIssues = null);

public interface IEquipmentFaultService
{
    bool IsConfigured { get; }

    Task<EquipmentFaultServiceOutcome> SubmitAsync(
        Guid userId,
        Guid stationId,
        EquipmentFaultSubmitRequest request,
        CancellationToken cancellationToken);

    Task<EquipmentFaultServiceOutcome> ListAsync(
        Guid stationId,
        int limit,
        CancellationToken cancellationToken);

    Task<EquipmentFaultServiceOutcome> GetByIdAsync(
        Guid stationId,
        Guid faultId,
        CancellationToken cancellationToken);

    Task<EquipmentFaultServiceOutcome> TransitionAsync(
        Guid userId,
        Guid stationId,
        Guid faultId,
        EquipmentFaultTransitionRequest request,
        CancellationToken cancellationToken);
}

public static class EquipmentFaultRequestGuard
{
    public static IReadOnlyList<ValidationIssue> ValidateSubmit(
        Guid stationId,
        Guid userId,
        EquipmentFaultSubmitRequest? request,
        DateTimeOffset now)
    {
        if (request is null)
            return [new("body", "طلب بلاغ العطل مطلوب.")];

        if (!TryParseSeverity(request.Severity, out var severity))
            return [new(nameof(request.Severity), "درجة شدة العطل غير معروفة.")];

        var report = new EquipmentFaultReport(
            stationId,
            userId,
            request.EquipmentCategory ?? string.Empty,
            request.EquipmentName ?? string.Empty,
            request.Description ?? string.Empty,
            severity,
            request.OccurredAt ?? default,
            request.IsOperationallyBlocking);

        return EquipmentFaultPolicy.Validate(report, now);
    }

    public static IReadOnlyList<ValidationIssue> ValidateTransition(
        Guid stationId,
        Guid faultId,
        EquipmentFaultStatus currentStatus,
        EquipmentFaultTransitionRequest? request,
        DateTimeOffset now)
    {
        if (request is null)
            return [new("body", "طلب انتقال الحالة مطلوب.")];
        if (!TryParseStatus(request.ToStatus, out var toStatus))
            return [new(nameof(request.ToStatus), "حالة العطل المطلوبة غير معروفة.")];

        var update = new MaintenanceProgressUpdate(
            faultId,
            stationId,
            currentStatus,
            toStatus,
            request.ProgressPercent ?? 0,
            now,
            request.Note);

        // For transitions that are pure workflow (UnderReview/Assigned/Rejected)
        // progress rules still apply when percent is supplied.
        var issues = new List<ValidationIssue>();
        if (!EquipmentFaultPolicy.CanTransition(currentStatus, toStatus))
            issues.Add(new(nameof(request.ToStatus), "انتقال حالة العطل غير مسموح وفق دورة حياة البلاغ."));
        if (request.Note is not null &&
            (string.IsNullOrWhiteSpace(request.Note) || request.Note.Trim().Length > 1000))
            issues.Add(new(nameof(request.Note), "ملاحظة الانتقال يجب ألا تكون فارغة وألا تتجاوز 1000 محرف."));
        if (request.ProgressPercent is < 0 or > 100)
            issues.Add(new(nameof(request.ProgressPercent), "نسبة الإنجاز يجب أن تكون بين 0 و100."));
        if (toStatus == EquipmentFaultStatus.Resolved && (request.ProgressPercent ?? 0) != 100)
            issues.Add(new(nameof(request.ProgressPercent), "لا يمكن تسجيل العطل محلولاً قبل اكتمال الإنجاز بنسبة 100."));
        if ((toStatus is EquipmentFaultStatus.Rejected or EquipmentFaultStatus.Closed) &&
            string.IsNullOrWhiteSpace(request.Note))
            issues.Add(new(nameof(request.Note), "ملاحظة الإغلاق أو الرفض مطلوبة."));

        // Keep progress policy alignment when progress fields are meaningful.
        if (toStatus is EquipmentFaultStatus.InProgress or EquipmentFaultStatus.Resolved)
            issues.AddRange(MaintenanceProgressPolicy.Validate(update, now)
                .Where(i => issues.All(existing => existing.Field != i.Field)));

        return issues;
    }

    public static bool TryParseSeverity(string? value, out EquipmentFaultSeverity severity)
        => Enum.TryParse(value, ignoreCase: true, out severity) && Enum.IsDefined(severity);

    public static bool TryParseStatus(string? value, out EquipmentFaultStatus status)
        => Enum.TryParse(value, ignoreCase: true, out status) && Enum.IsDefined(status);

    public static string PermissionForTransition(EquipmentFaultStatus toStatus) => toStatus switch
    {
        // Review / reject decisions
        EquipmentFaultStatus.UnderReview or EquipmentFaultStatus.Rejected => "equipment_fault.review",
        // Assignment to workshop staff
        EquipmentFaultStatus.Assigned => "equipment_fault.assign",
        // Technician progress (start / continue work) — not resolve/close
        EquipmentFaultStatus.InProgress => "equipment_fault.update",
        // Final resolve and close
        EquipmentFaultStatus.Resolved or EquipmentFaultStatus.Closed => "equipment_fault.resolve",
        _ => "equipment_fault.review"
    };
}

public sealed class SupabaseEquipmentFaultService(
    IHttpClientFactory clients,
    IConfiguration configuration) : IEquipmentFaultService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public async Task<EquipmentFaultServiceOutcome> SubmitAsync(
        Guid userId,
        Guid stationId,
        EquipmentFaultSubmitRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new(false, false, null, null);

        using var message = new HttpRequestMessage(
            HttpMethod.Post,
            $"{_url!.TrimEnd('/')}/rest/v1/rpc/metra_submit_equipment_fault");
        ApplyServiceAuth(message);
        message.Content = JsonContent.Create(new
        {
            p_user_id = userId,
            p_station_id = stationId,
            p_equipment_category = request.EquipmentCategory,
            p_equipment_name = request.EquipmentName,
            p_description = request.Description,
            p_severity = request.Severity,
            p_occurred_at = request.OccurredAt,
            p_is_operationally_blocking = request.IsOperationallyBlocking
        });

        return await SendAsync(message, cancellationToken);
    }

    public async Task<EquipmentFaultServiceOutcome> ListAsync(
        Guid stationId,
        int limit,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || limit is < 1 or > 100)
            return new(IsConfigured, false, null, null);

        var query =
            $"station_id=eq.{stationId:D}" +
            "&select=id,station_id,reporter_user_id,equipment_category,equipment_name,description,severity,status,is_operationally_blocking,occurred_at,assigned_to,progress_percent,progress_note,created_at,updated_at" +
            "&order=occurred_at.desc&limit=" + limit;

        using var message = new HttpRequestMessage(
            HttpMethod.Get,
            $"{_url!.TrimEnd('/')}/rest/v1/metra_equipment_faults?{query}");
        ApplyServiceAuth(message);
        return await SendAsync(message, cancellationToken);
    }

    
    public async Task<EquipmentFaultServiceOutcome> GetByIdAsync(
        Guid stationId,
        Guid faultId,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || faultId == Guid.Empty)
            return new(IsConfigured, false, null, null);

        // Station scope is enforced in the query filter and again by the endpoint permission gate.
        var query =
            $"id=eq.{faultId:D}&station_id=eq.{stationId:D}" +
            "&select=id,station_id,reporter_user_id,equipment_category,equipment_name,description,severity,status,is_operationally_blocking,occurred_at,assigned_to,progress_percent,progress_note,created_at,updated_at" +
            "&limit=1";
        using var message = new HttpRequestMessage(
            HttpMethod.Get,
            $"{_url!.TrimEnd('/')}/rest/v1/metra_equipment_faults?{query}");
        ApplyServiceAuth(message);

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

public async Task<EquipmentFaultServiceOutcome> TransitionAsync(
        Guid userId,
        Guid stationId,
        Guid faultId,
        EquipmentFaultTransitionRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new(false, false, null, null);

        using var message = new HttpRequestMessage(
            HttpMethod.Post,
            $"{_url!.TrimEnd('/')}/rest/v1/rpc/metra_transition_equipment_fault");
        ApplyServiceAuth(message);
        message.Content = JsonContent.Create(new
        {
            p_user_id = userId,
            p_station_id = stationId,
            p_fault_id = faultId,
            p_to_status = request.ToStatus,
            p_note = request.Note,
            p_progress_percent = request.ProgressPercent,
            p_assigned_to = request.AssignedTo
        });
        return await SendAsync(message, cancellationToken);
    }

    private void ApplyServiceAuth(HttpRequestMessage message)
    {
        message.Headers.TryAddWithoutValidation("apikey", _key);
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
    }

    private async Task<EquipmentFaultServiceOutcome> SendAsync(
        HttpRequestMessage message,
        CancellationToken cancellationToken)
    {
        try
        {
            using var response = await clients
                .CreateClient(nameof(SupabaseEquipmentFaultService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(cancellationToken);
                return new(true, false, MapFailure(body, response.StatusCode), null);
            }

            var data = await response.Content.ReadFromJsonAsync<JsonElement>(
                cancellationToken: cancellationToken);
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
                ? fallback
                : HttpStatusCode.ServiceUnavailable;

        if (body.Contains("station_equipment_fault_create_forbidden", StringComparison.Ordinal) ||
            body.Contains("station_equipment_fault_transition_forbidden", StringComparison.Ordinal))
            return HttpStatusCode.Forbidden;
        if (body.Contains("equipment_fault_not_found", StringComparison.Ordinal))
            return HttpStatusCode.NotFound;
        if (body.Contains("invalid_fault_state_transition", StringComparison.Ordinal) ||
            body.Contains("resolved_requires_full_progress", StringComparison.Ordinal))
            return HttpStatusCode.Conflict;
        if (body.Contains("invalid_fault", StringComparison.Ordinal) ||
            body.Contains("invalid_progress", StringComparison.Ordinal))
            return HttpStatusCode.BadRequest;

        return fallback is >= HttpStatusCode.BadRequest and < HttpStatusCode.InternalServerError
            ? fallback
            : HttpStatusCode.ServiceUnavailable;
    }
}

public static class EquipmentFaultEndpoints
{
    public static IEndpointRouteBuilder MapEquipmentFaultEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost(
            "/api/v1/stations/{stationId:guid}/equipment-faults",
            async (
                Guid stationId,
                EquipmentFaultSubmitRequest? request,
                HttpContext http,
                IEquipmentFaultService faults,
                CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId) || userId == Guid.Empty)
                    return Results.Unauthorized();

                var issues = EquipmentFaultRequestGuard.ValidateSubmit(
                    stationId, userId, request, DateTimeOffset.UtcNow);
                if (issues.Count > 0)
                    return Results.BadRequest(new { error = "validation_failed", issues });

                if (!faults.IsConfigured)
                    return Results.Problem(
                        title: "Equipment fault service unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var result = await faults.SubmitAsync(userId, stationId, request!, cancellationToken);
                if (!result.Succeeded)
                {
                    if (result.StatusCode == HttpStatusCode.Forbidden)
                        return Results.Forbid();
                    if (result.StatusCode == HttpStatusCode.BadRequest)
                        return Results.BadRequest(new { error = "invalid_equipment_fault" });
                    return Results.Problem(
                        title: "Equipment fault persistence unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }

                return Results.Json(result.Data, statusCode: StatusCodes.Status201Created);
            })
            .RequireStationPermission("equipment_fault.create")
            .WithTags("Maintenance")
            .WithName("SubmitEquipmentFault");

        endpoints.MapGet(
            "/api/v1/stations/{stationId:guid}/equipment-faults",
            async (
                Guid stationId,
                int? limit,
                IEquipmentFaultService faults,
                CancellationToken cancellationToken) =>
            {
                var take = limit ?? 50;
                if (take is < 1 or > 100)
                    return Results.BadRequest(new { error = "invalid_limit", maximum = 100 });

                if (!faults.IsConfigured)
                    return Results.Problem(
                        title: "Equipment fault service unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var result = await faults.ListAsync(stationId, take, cancellationToken);
                if (!result.Succeeded || result.Data is null)
                    return Results.Problem(
                        title: "Equipment fault list unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                return Results.Ok(result.Data);
            })
            .RequireStationPermission("equipment_fault.read")
            .WithTags("Maintenance")
            .WithName("ListEquipmentFaults");

        
        endpoints.MapGet(
            "/api/v1/stations/{stationId:guid}/equipment-faults/{faultId:guid}",
            async (
                Guid stationId,
                Guid faultId,
                IEquipmentFaultService faults,
                CancellationToken cancellationToken) =>
            {
                if (!faults.IsConfigured)
                    return Results.Problem(
                        title: "Equipment fault service unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var result = await faults.GetByIdAsync(stationId, faultId, cancellationToken);
                if (!result.Succeeded || result.Data is null)
                {
                    if (result.StatusCode == HttpStatusCode.NotFound)
                        return Results.NotFound(new { error = "equipment_fault_not_found" });
                    return Results.Problem(
                        title: "Equipment fault detail unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }

                // Defense in depth: reject cross-station leakage if storage ever returns a mismatched row.
                if (result.Data.Value.TryGetProperty("station_id", out var stationProp))
                {
                    if (!Guid.TryParse(stationProp.GetString(), out var rowStation) || rowStation != stationId)
                        return Results.NotFound(new { error = "equipment_fault_not_found" });
                }

                return Results.Ok(result.Data);
            })
            .RequireStationPermission("equipment_fault.read")
            .WithTags("Maintenance")
            .WithName("GetEquipmentFaultById");

endpoints.MapPost(
            "/api/v1/stations/{stationId:guid}/equipment-faults/{faultId:guid}/transitions",
            async (
                Guid stationId,
                Guid faultId,
                EquipmentFaultTransitionRequest? request,
                HttpContext http,
                IEquipmentFaultService faults,
                IStationAuthorizationService authorization,
                CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId) || userId == Guid.Empty)
                    return Results.Unauthorized();

                if (request is null ||
                    !EquipmentFaultRequestGuard.TryParseStatus(request.ToStatus, out var toStatus))
                    return Results.BadRequest(new { error = "invalid_fault_transition" });

                // Domain validation without requiring current status from client:
                // only structural checks here; database enforces transition matrix atomically.
                if (request.Note is not null &&
                    (string.IsNullOrWhiteSpace(request.Note) || request.Note.Trim().Length > 1000))
                    return Results.BadRequest(new { error = "invalid_transition_note" });
                if (request.ProgressPercent is < 0 or > 100)
                    return Results.BadRequest(new { error = "invalid_progress_percent" });
                if (toStatus == EquipmentFaultStatus.Resolved && (request.ProgressPercent ?? 0) != 100)
                    return Results.BadRequest(new { error = "resolved_requires_full_progress" });
                if ((toStatus is EquipmentFaultStatus.Rejected or EquipmentFaultStatus.Closed) &&
                    string.IsNullOrWhiteSpace(request.Note))
                    return Results.BadRequest(new { error = "transition_note_required" });

                var permission = EquipmentFaultRequestGuard.PermissionForTransition(toStatus);
                var allowed = await authorization.HasStationPermissionAsync(
                    userId, stationId, permission, cancellationToken);
                if (!allowed)
                    return Results.Forbid();

                if (!faults.IsConfigured)
                    return Results.Problem(
                        title: "Equipment fault service unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var result = await faults.TransitionAsync(
                    userId, stationId, faultId, request, cancellationToken);
                if (!result.Succeeded)
                {
                    if (result.StatusCode == HttpStatusCode.Forbidden)
                        return Results.Forbid();
                    if (result.StatusCode == HttpStatusCode.NotFound)
                        return Results.NotFound(new { error = "equipment_fault_not_found" });
                    if (result.StatusCode == HttpStatusCode.Conflict)
                        return Results.Conflict(new { error = "invalid_fault_state_transition" });
                    if (result.StatusCode == HttpStatusCode.BadRequest)
                        return Results.BadRequest(new { error = "invalid_fault_transition" });
                    return Results.Problem(
                        title: "Equipment fault transition unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }

                return Results.Ok(result.Data);
            })
            // Station membership gate; finer permission checked above.
            .RequireStationPermission("equipment_fault.read")
            .WithTags("Maintenance")
            .WithName("TransitionEquipmentFault");

        return endpoints;
    }
}
