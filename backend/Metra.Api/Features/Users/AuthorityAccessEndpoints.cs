using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;

namespace Metra.Api.Features.Users;

public sealed record AuthorityMembershipRequest(Guid? UserId, string? RoleCode, string? Reason,
    DateTimeOffset? ValidFrom, DateTimeOffset? ValidTo);
public sealed record AuthorityPermissionGrantRequest(string? PermissionCode, string? Reason,
    DateTimeOffset? ValidFrom, DateTimeOffset? ValidTo);
public sealed record AuthorityAccessDecisionRequest(string? Decision, string? Reason);
public sealed record AuthorityAccessRpcOutcome(bool IsConfigured, bool Succeeded,
    HttpStatusCode? StatusCode, JsonElement? Data);

public interface IAuthorityAccessService
{
    bool IsConfigured { get; }
    Task<AuthorityAccessRpcOutcome> CallAsync(string rpcName, object payload, CancellationToken cancellationToken);
}

public sealed class SupabaseAuthorityAccessService(
    IHttpClientFactory clients, IConfiguration configuration) : IAuthorityAccessService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps && !string.IsNullOrWhiteSpace(_key);

    public async Task<AuthorityAccessRpcOutcome> CallAsync(
        string rpcName, object payload, CancellationToken cancellationToken)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(rpcName) ||
            rpcName.Any(c => !char.IsAsciiLetterOrDigit(c) && c != '_'))
            return new(false, false, null, null);

        using var request = new HttpRequestMessage(
            HttpMethod.Post, $"{_url!.TrimEnd('/')}/rest/v1/rpc/{rpcName}");
        request.Headers.TryAddWithoutValidation("apikey", _key);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
        request.Content = JsonContent.Create(payload);

        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseAuthorityAccessService))
                .SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return new(true, false, response.StatusCode, null);
            var data = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: cancellationToken);
            return new(true, true, response.StatusCode, data);
        }
        catch (HttpRequestException) { return new(true, false, HttpStatusCode.ServiceUnavailable, null); }
        catch (JsonException) { return new(true, false, HttpStatusCode.ServiceUnavailable, null); }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        { return new(true, false, HttpStatusCode.ServiceUnavailable, null); }
    }
}

public static class AuthorityAccessEndpoints
{
    public static IEndpointRouteBuilder MapAuthorityAccessEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost("/api/v1/authorities/{authorityId:guid}/memberships", async (
            Guid authorityId, AuthorityMembershipRequest? request, HttpContext http,
            IAuthorityAccessService service, CancellationToken ct) =>
        {
            if (!TryActor(http, out var actor)) return Results.Unauthorized();
            if (authorityId == Guid.Empty || request is null ||
                string.IsNullOrWhiteSpace(request.RoleCode) || request.RoleCode.Length > 128 ||
                request.RoleCode.Any(char.IsControl) || !ValidReason(request.Reason) ||
                (request.ValidFrom is not null && request.ValidTo is not null && request.ValidTo <= request.ValidFrom))
                return Results.BadRequest(new { error = "invalid_authority_membership_request" });
            if (!service.IsConfigured) return Unavailable();
            var target = request.UserId ?? actor;
            var result = await service.CallAsync("request_authority_membership", new
            {
                p_user_id = target, p_authority_id = authorityId, p_role_code = request.RoleCode.Trim(),
                p_requested_by = actor, p_reason = request.Reason!.Trim(),
                p_valid_from = request.ValidFrom ?? DateTimeOffset.UtcNow, p_valid_to = request.ValidTo
            }, ct);
            return RequestResult(result, "authority_membership_request_failed");
        }).WithTags("Authority access").WithName("RequestAuthorityMembership");

        endpoints.MapPost("/api/v1/authorities/{authorityId:guid}/memberships/{membershipId:guid}/decision", async (
            Guid authorityId, Guid membershipId, AuthorityAccessDecisionRequest? request, HttpContext http,
            IAuthorityAccessService service, CancellationToken ct) =>
        {
            if (!TryActor(http, out var actor)) return Results.Unauthorized();
            if (authorityId == Guid.Empty || membershipId == Guid.Empty || !ValidDecision(request))
                return Results.BadRequest(new { error = "invalid_authority_membership_decision" });
            if (!service.IsConfigured) return Unavailable();
            var result = await service.CallAsync("decide_authority_membership", new
            {
                p_membership_id = membershipId, p_authority_id = authorityId, p_actor_user_id = actor,
                p_decision = request!.Decision, p_reason = request.Reason!.Trim()
            }, ct);
            return TransitionResult(result);
        }).WithTags("Authority access").WithName("DecideAuthorityMembership");

        endpoints.MapPost("/api/v1/authorities/{authorityId:guid}/memberships/{membershipId:guid}/revocation", async (
            Guid authorityId, Guid membershipId, AuthorityAccessDecisionRequest? request, HttpContext http,
            IAuthorityAccessService service, CancellationToken ct) =>
        {
            if (!TryActor(http, out var actor)) return Results.Unauthorized();
            if (authorityId == Guid.Empty || membershipId == Guid.Empty || request is null || !ValidReason(request.Reason))
                return Results.BadRequest(new { error = "invalid_authority_membership_revocation" });
            if (!service.IsConfigured) return Unavailable();
            var result = await service.CallAsync("revoke_authority_membership", new
            {
                p_membership_id = membershipId, p_authority_id = authorityId, p_actor_user_id = actor, p_reason = request.Reason!.Trim()
            }, ct);
            return TransitionResult(result);
        }).WithTags("Authority access").WithName("RevokeAuthorityMembership");

        endpoints.MapPost("/api/v1/authorities/{authorityId:guid}/permission-grants", async (
            Guid authorityId, AuthorityPermissionGrantRequest? request, HttpContext http,
            IAuthorityAccessService service, CancellationToken ct) =>
        {
            if (!TryActor(http, out var actor)) return Results.Unauthorized();
            if (authorityId == Guid.Empty || request is null ||
                string.IsNullOrWhiteSpace(request.PermissionCode) || request.PermissionCode.Length > 128 ||
                request.PermissionCode.Any(char.IsControl) || !ValidReason(request.Reason) ||
                (request.ValidFrom is not null && request.ValidTo is not null && request.ValidTo <= request.ValidFrom))
                return Results.BadRequest(new { error = "invalid_authority_permission_request" });
            if (!service.IsConfigured) return Unavailable();
            var result = await service.CallAsync("request_authority_permission_grant", new
            {
                p_user_id = actor, p_authority_id = authorityId,
                p_permission_code = request.PermissionCode.Trim(), p_reason = request.Reason!.Trim(),
                p_valid_from = request.ValidFrom ?? DateTimeOffset.UtcNow, p_valid_to = request.ValidTo
            }, ct);
            return RequestResult(result, "authority_permission_request_failed");
        }).WithTags("Authority access").WithName("RequestAuthorityPermissionGrant");

        endpoints.MapPost("/api/v1/authorities/{authorityId:guid}/permission-grants/{grantId:guid}/decision", async (
            Guid authorityId, Guid grantId, AuthorityAccessDecisionRequest? request, HttpContext http,
            IAuthorityAccessService service, CancellationToken ct) =>
        {
            if (!TryActor(http, out var actor)) return Results.Unauthorized();
            if (authorityId == Guid.Empty || grantId == Guid.Empty || !ValidDecision(request))
                return Results.BadRequest(new { error = "invalid_authority_permission_decision" });
            if (!service.IsConfigured) return Unavailable();
            var result = await service.CallAsync("decide_authority_permission_grant", new
            {
                p_grant_id = grantId, p_authority_id = authorityId, p_actor_user_id = actor,
                p_decision = request!.Decision, p_reason = request.Reason!.Trim()
            }, ct);
            return TransitionResult(result);
        }).WithTags("Authority access").WithName("DecideAuthorityPermissionGrant");

        endpoints.MapPost("/api/v1/authorities/{authorityId:guid}/permission-grants/{grantId:guid}/revocation", async (
            Guid authorityId, Guid grantId, AuthorityAccessDecisionRequest? request, HttpContext http,
            IAuthorityAccessService service, CancellationToken ct) =>
        {
            if (!TryActor(http, out var actor)) return Results.Unauthorized();
            if (authorityId == Guid.Empty || grantId == Guid.Empty || request is null || !ValidReason(request.Reason))
                return Results.BadRequest(new { error = "invalid_authority_permission_revocation" });
            if (!service.IsConfigured) return Unavailable();
            var result = await service.CallAsync("revoke_authority_permission_grant", new
            {
                p_grant_id = grantId, p_authority_id = authorityId, p_actor_user_id = actor, p_reason = request.Reason!.Trim()
            }, ct);
            return TransitionResult(result);
        }).WithTags("Authority access").WithName("RevokeAuthorityPermissionGrant");

        endpoints.MapGet("/api/v1/authorities/{authorityId:guid}/access-queue", async (
            Guid authorityId, string? kind, int? limit, HttpContext http,
            IAuthorityAccessService service, CancellationToken ct) =>
        {
            if (!TryActor(http, out var actor)) return Results.Unauthorized();
            var take = limit ?? 50;
            if (authorityId == Guid.Empty || kind is not ("membership" or "permission_grant") || take is < 1 or > 100)
                return Results.BadRequest(new { error = "invalid_authority_access_queue_request" });
            if (!service.IsConfigured) return Unavailable();
            var result = await service.CallAsync("get_authority_access_queue", new
            {
                p_authority_id = authorityId, p_target_kind = kind, p_actor_user_id = actor, p_limit = take
            }, ct);
            return ReadResult(result, "authority_access_queue_unavailable");
        }).WithTags("Authority access").WithName("GetAuthorityAccessQueue");

        endpoints.MapGet("/api/v1/authorities/{authorityId:guid}/access-audit", async (
            Guid authorityId, int? limit, HttpContext http, IAuthorityAccessService service, CancellationToken ct) =>
        {
            if (!TryActor(http, out var actor)) return Results.Unauthorized();
            var take = limit ?? 100;
            if (authorityId == Guid.Empty || take is < 1 or > 200)
                return Results.BadRequest(new { error = "invalid_authority_access_audit_request" });
            if (!service.IsConfigured) return Unavailable();
            var result = await service.CallAsync("get_authority_access_audit", new
            {
                p_authority_id = authorityId, p_actor_user_id = actor, p_limit = take
            }, ct);
            return ReadResult(result, "authority_access_audit_unavailable");
        }).WithTags("Authority access").WithName("GetAuthorityAccessAudit");



        endpoints.MapGet("/api/v1/authorities", async (
            IAuthorityAccessService service, CancellationToken ct) =>
        {
            if (!service.IsConfigured) return Unavailable();
            var result = await service.CallAsync("get_authority_catalogue", new { }, ct);
            return ReadResult(result, "authority_catalogue_unavailable");
        }).WithTags("Authority access").WithName("GetAuthorityCatalogue");

        endpoints.MapGet("/api/v1/authorities/{authorityId:guid}/membership-roles", async (
            Guid authorityId, IAuthorityAccessService service, CancellationToken ct) =>
        {
            if (authorityId == Guid.Empty) return Results.BadRequest(new { error = "invalid_authority_id" });
            if (!service.IsConfigured) return Unavailable();
            var result = await service.CallAsync("get_authority_membership_roles",
                new { p_authority_id = authorityId }, ct);
            return ReadResult(result, "authority_membership_roles_unavailable");
        }).WithTags("Authority access").WithName("GetAuthorityMembershipRoles");

        endpoints.MapGet("/api/v1/authorities/{authorityId:guid}/permission-options", async (
            Guid authorityId, HttpContext http, IAuthorityAccessService service, CancellationToken ct) =>
        {
            if (!TryActor(http, out var actor)) return Results.Unauthorized();
            if (authorityId == Guid.Empty) return Results.BadRequest(new { error = "invalid_authority_id" });
            if (!service.IsConfigured) return Unavailable();
            var result = await service.CallAsync("get_authority_permission_options",
                new { p_authority_id = authorityId, p_actor_user_id = actor }, ct);
            return ReadResult(result, "authority_permission_options_unavailable");
        }).WithTags("Authority access").WithName("GetAuthorityPermissionOptions");

        return endpoints;
    }

    private static bool TryActor(HttpContext http, out Guid actor) =>
        Guid.TryParse(http.User.FindFirstValue("sub"), out actor) && actor != Guid.Empty;

    private static bool ValidReason(string? reason) =>
        reason is { Length: >= 5 and <= 2000 } && reason == reason.Trim() &&
        !reason.Any(char.IsControl);

    private static bool ValidDecision(AuthorityAccessDecisionRequest? request) =>
        request is not null && (request.Decision is "approve" or "reject") && ValidReason(request.Reason);

    private static IResult Unavailable() =>
        Results.Problem(title: "Authority access service unavailable", statusCode: 503);

    private static IResult RequestResult(AuthorityAccessRpcOutcome result, string error)
    {
        if (!result.IsConfigured || !result.Succeeded) return MapFailure(result, error);
        return Results.Ok(new { id = result.Data });
    }

    private static IResult ReadResult(AuthorityAccessRpcOutcome result, string error)
    {
        if (!result.IsConfigured || !result.Succeeded) return MapFailure(result, error);
        return Results.Ok(result.Data);
    }

    private static IResult TransitionResult(AuthorityAccessRpcOutcome result)
    {
        if (!result.IsConfigured || !result.Succeeded) return MapFailure(result, "authority_access_transition_failed");
        var value = result.Data;
        if (value is { ValueKind: JsonValueKind.String })
            return value.Value.GetString() switch
            {
                "committed" => Results.Ok(new { status = "committed" }),
                "unauthorized" => Results.Forbid(),
                "not_found" => Results.NotFound(),
                "conflict" => Results.Conflict(new { error = "authority_access_state_conflict" }),
                _ => Unavailable()
            };
        return Unavailable();
    }

    private static IResult MapFailure(AuthorityAccessRpcOutcome result, string error) =>
        result.StatusCode switch
        {
            HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized => Results.Forbid(),
            HttpStatusCode.NotFound => Results.NotFound(),
            HttpStatusCode.Conflict => Results.Conflict(new { error }),
            HttpStatusCode.BadRequest => Results.BadRequest(new { error }),
            _ => Unavailable()
        };
}
