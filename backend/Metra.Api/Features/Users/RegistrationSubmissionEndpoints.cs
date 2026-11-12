using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;

using Metra.Api.Security;

namespace Metra.Api.Features.Users;

public sealed record RegistrationSubmissionRequest(
    string? FirstName,
    string? FatherName,
    string? LastName,
    string? Phone,
    string? RoleCode,
    Guid? StationId,
    string? TermsVersion,
    string? IdempotencyKey);

public sealed record RegistrationSubmissionOutcome(
    bool IsConfigured, bool Succeeded, HttpStatusCode? StatusCode, JsonElement? Data);

public interface IRegistrationSubmissionService
{
    bool IsConfigured { get; }
    Task<JsonElement?> GetRequestableRolesAsync(CancellationToken cancellationToken);
    Task<JsonElement?> GetStatusAsync(Guid userId, CancellationToken cancellationToken);
    Task<RegistrationSubmissionOutcome> SubmitAsync(
        Guid userId, RegistrationSubmissionRequest request, CancellationToken cancellationToken);
}

public sealed class SupabaseRegistrationSubmissionService(
    IHttpClientFactory clients, IConfiguration configuration) : IRegistrationSubmissionService
{
    private const string CurrentTermsVersion = "metra-terms-2026-11";
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public async Task<JsonElement?> GetRequestableRolesAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return null;
        using var message = CreateRequest(
            HttpMethod.Get,
            "/rest/v1/metra_role_catalogue?select=role_code,name_ar,name_en&is_active=eq.true&is_requestable=eq.true&order=role_code.asc");
        return await SendForJsonAsync(message, cancellationToken);
    }

    public async Task<JsonElement?> GetStatusAsync(Guid userId, CancellationToken cancellationToken)
    {
        if (!IsConfigured || userId == Guid.Empty) return null;
        using var message = CreateRequest(HttpMethod.Post, "/rest/v1/rpc/get_metra_registration_status");
        message.Content = JsonContent.Create(new { p_user_id = userId });
        return await SendForJsonAsync(message, cancellationToken);
    }

    public async Task<RegistrationSubmissionOutcome> SubmitAsync(
        Guid userId, RegistrationSubmissionRequest request, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return new(false, false, null, null);
        using var message = CreateRequest(
            HttpMethod.Post, "/rest/v1/rpc/submit_metra_registration_for_active_station");
        message.Content = JsonContent.Create(new
        {
            p_auth_user_id = userId,
            p_first_name = request.FirstName,
            p_father_name = request.FatherName,
            p_last_name = request.LastName,
            p_phone = request.Phone,
            p_role_code = request.RoleCode,
            p_station_id = request.StationId,
            p_terms_version = CurrentTermsVersion,
            p_submitted_at = DateTimeOffset.UtcNow,
            p_idempotency_key = request.IdempotencyKey
        });
        var data = await SendForJsonAsync(message, cancellationToken);
        return data is null
            ? new(true, false, HttpStatusCode.ServiceUnavailable, null)
            : new(true, true, HttpStatusCode.OK, data);
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
            using var response = await clients.CreateClient(nameof(SupabaseRegistrationSubmissionService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode) return null;
            return await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: cancellationToken);
        }
        catch (HttpRequestException) { return null; }
        catch (JsonException) { return null; }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested) { return null; }
    }
}

public static class RegistrationSubmissionRequestGuard
{
    public const string TermsVersion = "metra-terms-2026-11";

    public static string? GetError(RegistrationSubmissionRequest? request)
    {
        if (request is null) return "registration_request_required";
        if (!ValidRequired(request.FirstName, 120) ||
            !ValidRequired(request.FatherName, 120) ||
            !ValidRequired(request.LastName, 120))
            return "invalid_registration_name";
        if (request.Phone is { } phone &&
            (phone.Trim().Length is < 1 or > 40 || HasControlCharacters(phone)))
            return "invalid_registration_phone";
        if (!ValidRequired(request.RoleCode, 128)) return "invalid_registration_role";
        if (request.StationId is null || request.StationId == Guid.Empty) return "invalid_registration_station";
        if (request.TermsVersion != TermsVersion) return "invalid_registration_terms";
        if (!ValidRequired(request.IdempotencyKey, 128)) return "invalid_registration_idempotency_key";
        return null;
    }

    private static bool ValidRequired(string? value, int maxLength) =>
        !string.IsNullOrWhiteSpace(value) &&
        value == value.Trim() &&
        value.Length <= maxLength &&
        !HasControlCharacters(value);

    private static bool HasControlCharacters(string value) => value.Any(char.IsControl);
}

public static class RegistrationSubmissionRpcResult
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
            status.ValueKind != JsonValueKind.String) return null;
        return status.GetString();
    }
}

public static class RegistrationSubmissionEndpoints
{
    public static IEndpointRouteBuilder MapRegistrationSubmissionEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/registration-roles", async (
            IRegistrationSubmissionService service, CancellationToken cancellationToken) =>
        {
            if (!service.IsConfigured)
                return Results.Problem(title: "Registration service unavailable", statusCode: 503);
            var roles = await service.GetRequestableRolesAsync(cancellationToken);
            return roles is null
                ? Results.Problem(title: "Registration roles unavailable", statusCode: 503)
                : Results.Ok(roles.Value);
        })
        .WithTags("Users")
        .WithName("GetRequestableRegistrationRoles");

        endpoints.MapGet("/api/v1/account/registration-status", async (
            HttpContext http, IRegistrationSubmissionService service, CancellationToken cancellationToken) =>
        {
            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId))
                return Results.Unauthorized();
            if (!service.IsConfigured)
                return Results.Problem(title: "Registration status unavailable", statusCode: 503);
            var status = await service.GetStatusAsync(userId, cancellationToken);
            return status is null
                ? Results.Problem(title: "Registration status unavailable", statusCode: 503)
                : Results.Ok(status.Value);
        })
        .WithTags("Users")
        .WithName("GetMyRegistrationStatus");

        endpoints.MapPost("/api/v1/registration-requests", async (
            RegistrationSubmissionRequest? request, HttpContext http,
            IRegistrationSubmissionService service, CancellationToken cancellationToken) =>
        {
            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId))
                return Results.Unauthorized();
            var error = RegistrationSubmissionRequestGuard.GetError(request);
            if (error is not null) return Results.BadRequest(new { error });
            if (!service.IsConfigured)
                return Results.Problem(title: "Registration submission unavailable", statusCode: 503);

            var outcome = await service.SubmitAsync(userId, request!, cancellationToken);
            if (!outcome.Succeeded)
                return Results.Problem(title: "Registration submission persistence unavailable", statusCode: 503);

            var result = RegistrationSubmissionRpcResult.GetStatus(outcome.Data);
            if (result == "created")
                return Results.Created($"/api/v1/account/registration-status", outcome.Data);
            if (result == "already_created")
                return Results.Ok(outcome.Data);
            if (result is "existing_pending" or "auth_user_already_linked" or "conflict")
                return Results.Conflict(new { error = result });
            if (result is "station_not_available" or "role_not_requestable" or "terms_version_invalid")
                return Results.BadRequest(new { error = result });
            return Results.Problem(title: "Unexpected registration submission response", statusCode: 503);
        })
        .WithTags("Users")
        .WithName("SubmitRegistrationRequest");

        return endpoints;
    }
}
