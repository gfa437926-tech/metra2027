using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Stations;

public sealed record StationCatalogueReviewRequest(string? ExpectedStatus, string? Decision, string? Reason);
public sealed record StationCatalogueReviewOutcome(bool IsConfigured, bool Succeeded, HttpStatusCode? StatusCode, JsonElement? Data);

public interface IStationCatalogueReviewService
{
    bool IsConfigured { get; }
    Task<StationCatalogueReviewOutcome> DecideAsync(Guid stationId, Guid actorUserId, StationCatalogueReviewRequest request, CancellationToken cancellationToken);
}

public sealed class SupabaseStationCatalogueReviewService(IHttpClientFactory clients, IConfiguration configuration) : IStationCatalogueReviewService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public async Task<StationCatalogueReviewOutcome> DecideAsync(
        Guid stationId, Guid actorUserId, StationCatalogueReviewRequest request, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return new(false, false, null, null);

        using var message = new HttpRequestMessage(
            HttpMethod.Post, $"{_url!.TrimEnd('/')}/rest/v1/rpc/decide_station_catalogue_review");
        message.Headers.TryAddWithoutValidation("apikey", _key);
        message.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _key);
        message.Content = JsonContent.Create(new
        {
            p_station_id = stationId,
            p_expected_status = request.ExpectedStatus,
            p_actor_user_id = actorUserId,
            p_decision = request.Decision,
            p_reason = request.Reason,
            p_occurred_at = DateTimeOffset.UtcNow
        });

        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseStationCatalogueReviewService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return new(true, false, response.StatusCode, null);

            var data = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: cancellationToken);
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
}

public static class StationCatalogueReviewRequestGuard
{
    public static string? GetError(StationCatalogueReviewRequest? request)
    {
        if (request is null || request.ExpectedStatus != "pending")
            return "invalid_expected_station_status";
        if (request.Decision is not ("approved" or "rejected" or "changes_requested"))
            return "invalid_station_review_decision";
        if (string.IsNullOrWhiteSpace(request.Reason) ||
            request.Reason.Length > 2000 ||
            request.Reason != request.Reason.Trim() ||
            request.Reason.Trim().Length < 5)
            return "invalid_station_review_reason";
        return null;
    }
}

public static class StationCatalogueReviewEndpoints
{
    public static IEndpointRouteBuilder MapStationCatalogueReviewEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost("/api/v1/stations/{stationId:guid}/review", async (
            Guid stationId,
            StationCatalogueReviewRequest? request,
            HttpContext http,
            IStationCatalogueReviewService review,
            CancellationToken cancellationToken) =>
        {
            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorUserId))
                return Results.Unauthorized();

            var validationError = StationCatalogueReviewRequestGuard.GetError(request);
            if (validationError is not null)
                return Results.BadRequest(new { error = validationError });

            if (!review.IsConfigured)
                return Results.Problem(title: "Station review service unavailable", statusCode: 503);

            var outcome = await review.DecideAsync(stationId, actorUserId, request!, cancellationToken);
            if (!outcome.Succeeded)
            {
                if (outcome.StatusCode == HttpStatusCode.Forbidden) return Results.Forbid();
                if (outcome.StatusCode == HttpStatusCode.NotFound) return Results.NotFound();
                if (outcome.StatusCode == HttpStatusCode.Conflict)
                    return Results.Conflict(new { error = "station_review_state_conflict" });
                if (outcome.StatusCode == HttpStatusCode.BadRequest)
                    return Results.BadRequest(new { error = "station_review_rejected" });
                return Results.Problem(title: "Station review persistence unavailable", statusCode: 503);
            }

            return Results.Ok(outcome.Data);
        })
        .RequireStationOwnerAuthorityPermission("stations.catalogue.review")
        .WithTags("Stations")
        .RequireRateLimiting(MetraRateLimiting.PolicySensitive)
            .WithName("ReviewStationCatalogue");

        return endpoints;
    }
}
