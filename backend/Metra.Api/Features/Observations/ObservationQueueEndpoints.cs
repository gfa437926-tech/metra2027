using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Observations;

public interface IObservationQueueService
{
    bool IsConfigured { get; }
    Task<JsonElement?> GetSubmittedAsync(Guid stationId, int limit, CancellationToken cancellationToken);
}

/// <summary>
/// Reads only the submitted review queue. The service-role credential stays server-side;
/// station-level authorization is enforced by the endpoint before this service is called.
/// </summary>
public sealed class SupabaseObservationQueueService(
    IHttpClientFactory clients,
    IConfiguration configuration) : IObservationQueueService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public async Task<JsonElement?> GetSubmittedAsync(
        Guid stationId, int limit, CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || limit is < 1 or > 100)
            return null;

        var query = $"station_id=eq.{stationId:D}&status=eq.submitted&select=id,station_id,created_by,observation_type,observed_at,payload,status,submitted_at,created_at&order=observed_at.desc&limit={limit}";
        using var request = new HttpRequestMessage(
            HttpMethod.Get, $"{_url!.TrimEnd('/')}/rest/v1/metra_observations?{query}");
        request.Headers.TryAddWithoutValidation("apikey", _key);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);

        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseObservationQueueService))
                .SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return null;

            return await response.Content.ReadFromJsonAsync<JsonElement>(
                cancellationToken: cancellationToken);
        }
        catch (HttpRequestException)
        {
            return null;
        }
        catch (JsonException)
        {
            // A malformed PostgREST response must fail closed as an unavailable queue.
            return null;
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return null;
        }
    }
}

public static class ObservationQueueEndpoints
{
    public static IEndpointRouteBuilder MapObservationQueueEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/stations/{stationId:guid}/observations",
            async (Guid stationId, int? limit, HttpContext http,
                IStationAuthorizationService authorization,
                IObservationQueueService queue,
                CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId))
                    return Results.Unauthorized();

                var limitError = ObservationQueueRequestGuard.GetLimitError(limit);
                if (limitError is not null)
                    return Results.BadRequest(new { error = limitError, maximum = 100 });
                var take = limit ?? 50;

                if (!authorization.IsConfigured || !queue.IsConfigured)
                    return Results.Problem(
                        title: "Observation queue unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                // A reviewer may hold the generic review permission or a decision-specific grant.
                var permissions = new[]
                {
                    "observation.review",
                    "observation.approve",
                    "observation.return_for_correction"
                };
                var allowed = false;
                foreach (var permission in permissions)
                {
                    if (await authorization.HasStationPermissionAsync(
                        userId, stationId, permission, cancellationToken))
                    {
                        allowed = true;
                        break;
                    }
                }

                if (!allowed)
                    return Results.Forbid();

                var data = await queue.GetSubmittedAsync(stationId, take, cancellationToken);
                if (data is null)
                    return Results.Problem(title: "Observation queue read failed",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                return Results.Ok(data.Value);
            })
            .WithTags("Observations")
            .WithName("GetStationObservationReviewQueue");

        return endpoints;
    }
}

public static class ObservationQueueRequestGuard
{
    public static string? GetLimitError(int? limit) =>
        limit is not null and (< 1 or > 100) ? "invalid_limit" : null;
}
