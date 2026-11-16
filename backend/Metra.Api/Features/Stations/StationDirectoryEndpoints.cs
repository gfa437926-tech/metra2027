using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Stations;

public interface IStationDirectoryService
{
    bool IsConfigured { get; }
    Task<JsonElement?> GetStationsAsync(
        int limit, int offset, string? stationType, CancellationToken cancellationToken);
}

/// <summary>
/// Read-only catalogue projection. The service-role key is server-only; callers
/// must apply station/authority authorization before returning any catalogue rows.
/// </summary>
public sealed class SupabaseStationDirectoryService(
    IHttpClientFactory clients,
    IConfiguration configuration) : IStationDirectoryService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
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

public static class StationDirectoryVisibility
{
    // These are existing permission codes already enforced by the API/RPC contract.
    // A station is visible only if at least one current station permission succeeds,
    // or the user has the approved owner-authority catalogue-review permission.
    private static readonly string[] StationReadPermissions =
    [
        "observation.create",
        "observation.review",
        "observation.approve",
        "observation.return_for_correction",
        "users.station.manage"
    ];

    public static async Task<bool> CanViewAsync(
        IStationAuthorizationService authorization,
        Guid userId,
        Guid stationId,
        CancellationToken cancellationToken)
    {
        if (!authorization.IsConfigured || userId == Guid.Empty || stationId == Guid.Empty)
            return false;

        foreach (var permission in StationReadPermissions)
        {
            if (await authorization.HasStationPermissionAsync(
                    userId, stationId, permission, cancellationToken))
                return true;
        }

        return await authorization.HasStationOwnerAuthorityPermissionAsync(
            userId, stationId, "stations.catalogue.review", cancellationToken);
    }
}

public static class StationDirectoryEndpoints
{
    private const int PageSize = 500;
    private const int MaximumCatalogueRows = 10_000;

    public static IEndpointRouteBuilder MapStationDirectoryEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/stations", async (
            int? limit,
            int? offset,
            string? stationType,
            HttpContext http,
            IStationDirectoryService directory,
            IStationAuthorizationService authorization,
            CancellationToken cancellationToken) =>
        {
            var take = limit ?? 250;
            var skip = offset ?? 0;
            if (take is < 1 or > 500 || skip < 0)
                return Results.BadRequest(new { error = "invalid_pagination", maxLimit = 500 });

            if (stationType is not null &&
                stationType is not ("classic" or "automatic" or "synoptic"))
                return Results.BadRequest(new { error = "invalid_station_type" });

            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId) || userId == Guid.Empty)
                return Results.Unauthorized();

            if (!directory.IsConfigured || !authorization.IsConfigured)
                return Results.Problem(
                    title: "Station directory or authorization service unavailable",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            // Fetch the catalogue in bounded pages before applying user-specific
            // filtering. Filtering after PostgREST pagination would otherwise hide
            // a user's assigned station when unrelated rows precede it.
            var catalogue = new List<JsonElement>();
            for (var pageOffset = 0; pageOffset < MaximumCatalogueRows; pageOffset += PageSize)
            {
                var page = await directory.GetStationsAsync(
                    PageSize, pageOffset, stationType, cancellationToken);
                if (page is null || page.Value.ValueKind != JsonValueKind.Array)
                    return Results.Problem(
                        title: "Station directory read failed",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var pageRows = page.Value.EnumerateArray().Select(row => row.Clone()).ToArray();
                catalogue.AddRange(pageRows);
                if (pageRows.Length < PageSize)
                    break;

                if (catalogue.Count >= MaximumCatalogueRows)
                    return Results.Problem(
                        title: "Station catalogue exceeds the safe directory limit",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
            }

            var visible = new bool[catalogue.Count];
            await Parallel.ForEachAsync(
                Enumerable.Range(0, catalogue.Count),
                new ParallelOptions
                {
                    MaxDegreeOfParallelism = 8,
                    CancellationToken = cancellationToken
                },
                async (index, token) =>
                {
                    var row = catalogue[index];
                    if (!row.TryGetProperty("id", out var idValue) ||
                        idValue.ValueKind != JsonValueKind.String ||
                        !Guid.TryParse(idValue.GetString(), out var stationId) ||
                        stationId == Guid.Empty)
                        return;

                    visible[index] = await StationDirectoryVisibility.CanViewAsync(
                        authorization, userId, stationId, token);
                });

            var authorizedRows = catalogue.Where((_, index) => visible[index]).ToArray();
            var result = authorizedRows.Skip(skip).Take(take).ToArray();
            return Results.Ok(result);
        })
        .WithTags("Stations")
        .WithName("GetStationDirectory");

        return endpoints;
    }
}
