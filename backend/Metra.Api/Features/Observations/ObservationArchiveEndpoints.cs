using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text.Json;

namespace Metra.Api.Features.Observations;

public interface IObservationArchiveService
{
    bool IsConfigured { get; }
    Task<JsonElement?> GetPageAsync(
        Guid actorId, Guid stationId, string? observationType,
        DateTimeOffset? fromUtc, DateTimeOffset? toUtc,
        int limit, int offset, CancellationToken cancellationToken);
    Task<JsonElement?> GetDetailAsync(
        Guid actorId, Guid stationId, Guid observationId,
        CancellationToken cancellationToken);
}

/// <summary>
/// Reads imported, source-preserving archive envelopes through database RPCs.
/// The RPC rechecks active account, explicit archive permission, station assignment
/// and station state in the same database statement as the archive read.
/// The service-role credential is server-only and is never returned to clients.
/// </summary>
public sealed class SupabaseObservationArchiveService(
    IHttpClientFactory clients,
    IConfiguration configuration) : IObservationArchiveService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public Task<JsonElement?> GetPageAsync(
        Guid actorId, Guid stationId, string? observationType,
        DateTimeOffset? fromUtc, DateTimeOffset? toUtc,
        int limit, int offset, CancellationToken cancellationToken)
    {
        var body = new
        {
            p_actor_user_id = actorId,
            p_station_id = stationId,
            p_observation_type = observationType,
            p_from_utc = fromUtc?.ToUniversalTime(),
            p_to_utc = toUtc?.ToUniversalTime(),
            p_limit = limit,
            p_offset = offset
        };
        return InvokeAsync("metra_station_observation_archive_page", body, cancellationToken);
    }

    public Task<JsonElement?> GetDetailAsync(
        Guid actorId, Guid stationId, Guid observationId,
        CancellationToken cancellationToken)
    {
        var body = new
        {
            p_actor_user_id = actorId,
            p_station_id = stationId,
            p_observation_id = observationId
        };
        return InvokeAsync("metra_station_observation_archive_detail", body, cancellationToken);
    }

    private async Task<JsonElement?> InvokeAsync(
        string functionName, object body, CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return null;

        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"{_url!.TrimEnd('/')}/rest/v1/rpc/{functionName}")
        {
            Content = JsonContent.Create(body)
        };
        request.Headers.TryAddWithoutValidation("apikey", _key);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);

        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseObservationArchiveService))
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

public static class ObservationArchiveEndpoints
{
    public static IEndpointRouteBuilder MapObservationArchiveEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
            "/api/v1/stations/{stationId:guid}/observations/archive",
            async (Guid stationId, string? type, DateTimeOffset? fromUtc,
                DateTimeOffset? toUtc, int? limit, int? offset, HttpContext http,
                IObservationArchiveService archive, CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorId))
                    return Results.Unauthorized();

                var error = ObservationArchiveRequestGuard.GetError(
                    type, fromUtc, toUtc, limit, offset);
                if (error is not null)
                    return Results.BadRequest(new { error });

                if (!archive.IsConfigured)
                    return Results.Problem(
                        title: "Observation archive unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var data = await archive.GetPageAsync(
                    actorId, stationId, type, fromUtc, toUtc,
                    limit ?? 50, offset ?? 0, cancellationToken);
                if (data is null)
                    return Results.Problem(
                        title: "Observation archive read failed",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                if (!data.Value.TryGetProperty("authorized", out var authorized) ||
                    authorized.ValueKind != JsonValueKind.True)
                    return Results.Forbid();

                return Results.Ok(data.Value);
            })
            .WithTags("Observations")
            .WithName("GetStationObservationArchive");

        endpoints.MapGet(
            "/api/v1/stations/{stationId:guid}/observations/{observationId:guid}",
            async (Guid stationId, Guid observationId, HttpContext http,
                IObservationArchiveService archive, CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorId))
                    return Results.Unauthorized();

                if (!archive.IsConfigured)
                    return Results.Problem(
                        title: "Observation archive unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var data = await archive.GetDetailAsync(
                    actorId, stationId, observationId, cancellationToken);
                if (data is null)
                    return Results.Problem(
                        title: "Observation archive read failed",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                if (!data.Value.TryGetProperty("authorized", out var authorized) ||
                    authorized.ValueKind != JsonValueKind.True)
                    return Results.Forbid();

                if (!data.Value.TryGetProperty("found", out var found) ||
                    found.ValueKind != JsonValueKind.True)
                    return Results.NotFound();

                return Results.Ok(data.Value);
            })
            .WithTags("Observations")
            .WithName("GetStationObservationArchiveDetail");

        return endpoints;
    }
}

public static class ObservationArchiveRequestGuard
{
    private static readonly HashSet<string> AllowedTypes = new(StringComparer.Ordinal)
    {
        "daily", "hourly", "climate", "soil", "agricultural", "phenomenon", "fieldclimate"
    };

    public static string? GetError(
        string? type, DateTimeOffset? fromUtc, DateTimeOffset? toUtc,
        int? limit, int? offset)
    {
        if (type is not null && !AllowedTypes.Contains(type))
            return "invalid_observation_type";
        if (fromUtc is not null && fromUtc.Value.Offset != TimeSpan.Zero)
            return "utc_offset_required";
        if (toUtc is not null && toUtc.Value.Offset != TimeSpan.Zero)
            return "utc_offset_required";
        if (fromUtc is not null && toUtc is not null && fromUtc >= toUtc)
            return "invalid_time_range";
        if (limit is not null and (< 1 or > 100))
            return "invalid_limit";
        if (offset is not null and (< 0 or > 100000))
            return "invalid_offset";
        return null;
    }
}
