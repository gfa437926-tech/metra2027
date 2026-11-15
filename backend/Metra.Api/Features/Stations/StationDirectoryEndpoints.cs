using Metra.Api.Security;
using System.Net.Http.Headers;
using System.Text.Json;

namespace Metra.Api.Features.Stations;

public interface IStationDirectoryService
{
    bool IsConfigured { get; }
    Task<JsonElement?> GetStationsAsync(
        int limit, int offset, string? stationType, CancellationToken cancellationToken);
}

/// <summary>
/// Read-only authenticated directory projection. Only non-demo catalogue records
/// are returned; operational membership and write permissions remain server-side.
/// </summary>
public sealed class SupabaseStationDirectoryService(
    IHttpClientFactory clients,
    IConfiguration configuration) : IStationDirectoryService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];
    private readonly bool _legacyAdapterExplicitlyEnabled =
        configuration.GetValue<bool>("Features:LegacyStationDirectoryEnabled");

    // This adapter still targets the retired public.station_catalogue schema and
    // uses service_role (BYPASSRLS). Keep it disabled by default. It may only be
    // enabled in an explicitly isolated legacy compatibility environment; the
    // greenfield station directory must use the reviewed catalog.* contract and
    // a caller-scoped least-privilege identity.
    public bool IsConfigured =>
        _legacyAdapterExplicitlyEnabled &&
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public async Task<JsonElement?> GetStationsAsync(
        int limit, int offset, string? stationType, CancellationToken cancellationToken)
    {
        if (!IsConfigured || limit is < 1 or > 500 || offset < 0)
            return null;

        var query =
            "select=id,local_station_code,wmo_station_id,name_ar,name_en,station_type," +
            "operational_status,approval_status,is_demo,elevation_m,station_coordinates(latitude,longitude,coordinate_source,accuracy_m)" +
            "&is_demo=eq.false&station_coordinates.valid_to=is.null" +
            "&order=name_ar.asc&limit=" + limit + "&offset=" + offset;
        if (!string.IsNullOrWhiteSpace(stationType))
            query += "&station_type=eq." + Uri.EscapeDataString(stationType);

        using var request = new HttpRequestMessage(
            HttpMethod.Get, $"{_url!.TrimEnd('/')}/rest/v1/station_catalogue?{query}");
        request.Headers.TryAddWithoutValidation("apikey", _key);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
        request.Headers.TryAddWithoutValidation("Prefer", "count=exact");

        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseStationDirectoryService))
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

public static class StationDirectoryEndpoints
{
    public static IEndpointRouteBuilder MapStationDirectoryEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/stations", async (
            int? limit,
            int? offset,
            string? stationType,
            IStationDirectoryService directory,
            CancellationToken cancellationToken) =>
        {
            var take = limit ?? 250;
            var skip = offset ?? 0;
            if (take is < 1 or > 500 || skip < 0)
                return Results.BadRequest(new { error = "invalid_pagination", maxLimit = 500 });

            if (stationType is not null &&
                stationType is not ("classic" or "automatic" or "synoptic"))
                return Results.BadRequest(new { error = "invalid_station_type" });

            if (!directory.IsConfigured)
                return Results.Problem(
                    title: "Station directory unavailable",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            var stations = await directory.GetStationsAsync(
                take, skip, stationType, cancellationToken);
            if (stations is null)
                return Results.Problem(
                    title: "Station directory read failed",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            return Results.Ok(stations.Value);
        })
        .WithTags("Stations")
        .RequireRateLimiting(MetraRateLimiting.PolicyRead)
            .WithName("GetStationDirectory");

        
        endpoints.MapGet("/api/v2/stations", async (
            HttpContext context,
            int? limit,
            int? offset,
            string? stationType,
            IGreenfieldStationDirectoryReader directory,
            CancellationToken cancellationToken) =>
        {
            var take = limit ?? 250;
            var skip = offset ?? 0;
            if (take is < 1 or > 500 || skip < 0)
                return Results.BadRequest(new { error = "invalid_pagination", maxLimit = 500 });

            if (stationType is not null &&
                (stationType.Length is 0 or > 64 ||
                 !stationType.All(character => char.IsAsciiLetterOrDigit(character) ||
                     character is '_' or '-')))
                return Results.BadRequest(new { error = "invalid_station_type" });

            if (!context.User.Identity?.IsAuthenticated ?? true)
                return Results.Unauthorized();

            if (!AuthenticationHeaderValue.TryParse(
                    context.Request.Headers.Authorization, out var authorization) ||
                !string.Equals(authorization.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase) ||
                string.IsNullOrWhiteSpace(authorization.Parameter))
                return Results.Unauthorized();

            if (!directory.IsConfigured)
                return Results.Problem(
                    title: "Greenfield station directory unavailable",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            var result = await directory.GetStationsAsync(
                authorization.Parameter, take, skip, stationType, cancellationToken);
            if (result is null || !result.Succeeded)
                return Results.Problem(
                    title: "Greenfield station directory read failed",
                    detail: "The caller-scoped catalog projection is unavailable or invalid.",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            return Results.Ok(result.Stations);
        })
        .WithTags("Stations")
        .RequireRateLimiting(MetraRateLimiting.PolicyRead)
        .WithName("GetGreenfieldStationDirectory");

        return endpoints;
    }
}
