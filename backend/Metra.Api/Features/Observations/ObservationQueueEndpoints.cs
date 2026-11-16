using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Observations;

public interface IObservationQueueService
{
    bool IsConfigured { get; }
    Task<JsonElement?> GetSubmittedAsync(Guid actorUserId, Guid stationId, int limit, CancellationToken cancellationToken);
}

/// <summary>
/// Calls the actor-bound atomic read RPC. The actor ID is derived from the validated JWT
/// by the endpoint; the service-role credential remains server-side.
/// </summary>
public sealed class SupabaseObservationQueueService(
    IHttpClientFactory clients, IConfiguration configuration) : IObservationQueueService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps && !string.IsNullOrWhiteSpace(_key);

    public async Task<JsonElement?> GetSubmittedAsync(
        Guid actorUserId, Guid stationId, int limit, CancellationToken cancellationToken)
    {
        if (!IsConfigured || actorUserId == Guid.Empty || stationId == Guid.Empty || limit is < 1 or > 100)
            return null;

        using var request = new HttpRequestMessage(
            HttpMethod.Post, $"{_url!.TrimEnd('/')}/rest/v1/rpc/get_station_observation_review_queue_atomic");
        request.Headers.TryAddWithoutValidation("apikey", _key);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
        request.Content = JsonContent.Create(new {
            p_actor_user_id = actorUserId, p_station_id = stationId, p_limit = limit
        });

        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseObservationQueueService))
                .SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                var mappedStatus = await SupabaseRpcErrorHandling.MapDatabaseErrorStatusAsync(response, cancellationToken);
                if (mappedStatus == HttpStatusCode.Forbidden)
                    throw new StationReadForbiddenException();
                return null;
            }
            return await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: cancellationToken);
        }
        catch (HttpRequestException) { return null; }
        catch (JsonException) { return null; }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested) { return null; }
    }
}

public static class ObservationQueueEndpoints
{
    public static IEndpointRouteBuilder MapObservationQueueEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/stations/{stationId:guid}/observations",
            async (Guid stationId, int? limit, HttpContext http,
                IObservationQueueService queue, CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorUserId))
                    return Results.Unauthorized();

                var limitError = ObservationQueueRequestGuard.GetLimitError(limit);
                if (limitError is not null)
                    return Results.BadRequest(new { error = limitError, maximum = 100 });
                var take = limit ?? 50;

                if (!queue.IsConfigured)
                    return Results.Problem(title: "Observation queue unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                JsonElement? data;
                try { data = await queue.GetSubmittedAsync(actorUserId, stationId, take, cancellationToken); }
                catch (StationReadForbiddenException)
                {
                    return Results.Json(new { code = "station_permission_denied" }, statusCode: 403);
                }
                if (data is null)
                    return Results.Problem(title: "Observation queue read failed",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                return Results.Ok(data.Value);
            })
            .WithTags("Observations")
            .RequireAuthorization()
            .RequireRateLimiting(MetraRateLimiting.PolicyRead)
            .WithName("GetStationObservationReviewQueue");
        return endpoints;
    }
}

public static class ObservationQueueRequestGuard
{
    public static string? GetLimitError(int? limit) =>
        limit is not null and (< 1 or > 100) ? "invalid_limit" : null;
}
