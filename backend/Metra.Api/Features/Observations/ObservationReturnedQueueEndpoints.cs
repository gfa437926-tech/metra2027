using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Observations;

public interface IObservationReturnedQueueService
{
    bool IsConfigured { get; }

    /// <summary>
    /// Returns only returned observations created by the authenticated user within the station scope.
    /// </summary>
    Task<JsonElement?> GetReturnedOwnedAsync(
        Guid stationId,
        Guid userId,
        int limit,
        CancellationToken cancellationToken);
}

public sealed class SupabaseObservationReturnedQueueService(
    IHttpClientFactory clients,
    IConfiguration configuration) : IObservationReturnedQueueService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public async Task<JsonElement?> GetReturnedOwnedAsync(
        Guid stationId,
        Guid userId,
        int limit,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || userId == Guid.Empty || limit is < 1 or > 100)
            return null;

        // Station scope + ownership enforced in the query before any client projection.
        var query =
            $"station_id=eq.{stationId:D}" +
            $"&created_by=eq.{userId:D}" +
            "&status=eq.returned" +
            "&select=id,station_id,created_by,observation_type,observed_at,payload,status,submitted_at,reviewed_at,review_note,created_at" +
            "&order=reviewed_at.desc.nullslast&limit=" + limit;

        using var request = new HttpRequestMessage(
            HttpMethod.Get,
            $"{_url!.TrimEnd('/')}/rest/v1/metra_observations?{query}");
        request.Headers.TryAddWithoutValidation("apikey", _key);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);

        try
        {
            using var response = await clients
                .CreateClient(nameof(SupabaseObservationReturnedQueueService))
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
            return null;
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return null;
        }
    }
}

public static class ObservationReturnedQueueEndpoints
{
    public static IEndpointRouteBuilder MapObservationReturnedQueueEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
            "/api/v1/stations/{stationId:guid}/observations/returned",
            async (
                Guid stationId,
                int? limit,
                HttpContext http,
                IObservationReturnedQueueService queue,
                CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId) || userId == Guid.Empty)
                    return Results.Unauthorized();

                var limitError = ObservationQueueRequestGuard.GetLimitError(limit);
                if (limitError is not null)
                    return Results.BadRequest(new { error = limitError, maximum = 100 });
                var take = limit ?? 50;

                if (!queue.IsConfigured)
                    return Results.Problem(
                        title: "Returned observation queue unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var data = await queue.GetReturnedOwnedAsync(
                    stationId, userId, take, cancellationToken);
                if (data is null)
                    return Results.Problem(
                        title: "Returned observation queue read failed",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                return Results.Ok(data.Value);
            })
            // Creator resubmits with submit permission; create alone is insufficient for write-back.
            .RequireStationPermission("observation.submit")
            .WithTags("Observations")
            .WithName("GetStationReturnedObservations");

        return endpoints;
    }
}
