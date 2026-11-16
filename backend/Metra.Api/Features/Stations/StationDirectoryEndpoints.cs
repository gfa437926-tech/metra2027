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
    Task<IReadOnlyList<Guid>?> GetAssignedStationIdsAsync(
        Guid userId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Guid>?> GetAuthorityIdsAsync(
        Guid userId, CancellationToken cancellationToken);
    Task<JsonElement?> GetStationsByScopeAsync(
        IReadOnlyCollection<Guid> stationIds,
        IReadOnlyCollection<Guid> authorityIds,
        string? stationType,
        CancellationToken cancellationToken);
}

/// <summary>
/// Read-only catalogue projection. The service-role key is server-only. The
/// scoped query accepts only station and authority IDs obtained from the
/// authenticated user's active assignment/membership read models.
/// </summary>
public sealed class SupabaseStationDirectoryService(
    IHttpClientFactory clients,
    IConfiguration configuration) : IStationDirectoryService
{
    private const int PageSize = 500;
    private const int MaximumCatalogueRows = 10_000;
    private const int MaximumAssignments = 1_000;
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public Task<JsonElement?> GetStationsAsync(
        int limit, int offset, string? stationType, CancellationToken cancellationToken)
    {
        if (limit is < 1 or > PageSize || offset < 0)
            return Task.FromResult<JsonElement?>(null);

        var filter = BuildStationSelect();
        filter += "&is_demo=eq.false&station_coordinates.valid_to=is.null";
        filter += "&order=name_ar.asc&limit=" + limit + "&offset=" + offset;
        if (!string.IsNullOrWhiteSpace(stationType))
            filter += "&station_type=eq." + Uri.EscapeDataString(stationType);

        return GetRowsAsync("station_catalogue?" + filter, cancellationToken);
    }

    public async Task<IReadOnlyList<Guid>?> GetAssignedStationIdsAsync(
        Guid userId, CancellationToken cancellationToken)
    {
        if (!IsConfigured || userId == Guid.Empty)
            return null;

        var now = DateTimeOffset.UtcNow;
        var encodedNow = Uri.EscapeDataString(now.ToString("O"));
        var query = "station_assignments?select=station_id" +
                    "&user_id=eq." + userId +
                    "&approval_status=eq.approved" +
                    "&valid_from=lte." + encodedNow +
                    "&or=" + Uri.EscapeDataString($"(valid_to.is.null,valid_to.gt.{now:O})") +
                    "&limit=" + (MaximumAssignments + 1);
        var rows = await GetRowsAsync(query, cancellationToken);
        if (rows is null || rows.Value.ValueKind != JsonValueKind.Array ||
            rows.Value.GetArrayLength() > MaximumAssignments)
            return null;

        return ReadGuidColumn(rows.Value, "station_id");
    }

    public async Task<IReadOnlyList<Guid>?> GetAuthorityIdsAsync(
        Guid userId, CancellationToken cancellationToken)
    {
        if (!IsConfigured || userId == Guid.Empty)
            return null;

        var now = DateTimeOffset.UtcNow;
        var encodedNow = Uri.EscapeDataString(now.ToString("O"));
        var query = "authority_memberships?select=authority_id" +
                    "&user_id=eq." + userId +
                    "&approval_status=eq.approved" +
                    "&valid_from=lte." + encodedNow +
                    "&or=" + Uri.EscapeDataString($"(valid_to.is.null,valid_to.gt.{now:O})") +
                    "&limit=" + (MaximumAssignments + 1);
        var rows = await GetRowsAsync(query, cancellationToken);
        if (rows is null || rows.Value.ValueKind != JsonValueKind.Array ||
            rows.Value.GetArrayLength() > MaximumAssignments)
            return null;

        return ReadGuidColumn(rows.Value, "authority_id");
    }

    public async Task<JsonElement?> GetStationsByScopeAsync(
        IReadOnlyCollection<Guid> stationIds,
        IReadOnlyCollection<Guid> authorityIds,
        string? stationType,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationIds.Count > MaximumAssignments ||
            authorityIds.Count > MaximumAssignments)
            return null;

        var ids = stationIds.Where(id => id != Guid.Empty).Distinct().ToArray();
        var authorities = authorityIds.Where(id => id != Guid.Empty).Distinct().ToArray();
        if (ids.Length == 0 && authorities.Length == 0)
            return JsonDocument.Parse("[]").RootElement.Clone();

        var filters = new List<string>();
        if (ids.Length > 0)
            filters.Add("id.in.(" + string.Join(",", ids) + ")");
        if (authorities.Length > 0)
            filters.Add("owner_authority_id.in.(" + string.Join(",", authorities) + ")");

        var scopeFilter = filters.Count == 1
            ? filters[0]
            : "or=" + Uri.EscapeDataString("(" + string.Join(",", filters) + ")");
        var rows = new List<JsonElement>();

        for (var offset = 0; offset < MaximumCatalogueRows; offset += PageSize)
        {
            var query = BuildStationSelect() +
                        "&is_demo=eq.false&station_coordinates.valid_to=is.null&" +
                        scopeFilter +
                        "&order=name_ar.asc&limit=" + PageSize + "&offset=" + offset;
            if (!string.IsNullOrWhiteSpace(stationType))
                query += "&station_type=eq." + Uri.EscapeDataString(stationType);

            var page = await GetRowsAsync("station_catalogue?" + query, cancellationToken);
            if (page is null || page.Value.ValueKind != JsonValueKind.Array)
                return null;

            var pageRows = page.Value.EnumerateArray().Select(row => row.Clone()).ToArray();
            rows.AddRange(pageRows);
            if (pageRows.Length < PageSize)
                return ToJsonArray(rows);

            if (rows.Count >= MaximumCatalogueRows)
                return null;
        }

        return ToJsonArray(rows);
    }

    private async Task<JsonElement?> GetRowsAsync(string path, CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return null;

        using var request = new HttpRequestMessage(
            HttpMethod.Get, $"{_url!.TrimEnd('/')}/rest/v1/{path}");
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

    private static string BuildStationSelect() =>
        "select=id,owner_authority_id,local_station_code,wmo_station_id,name_ar,name_en,station_type," +
        "operational_status,approval_status,is_demo,elevation_m,station_coordinates(latitude,longitude,coordinate_source,accuracy_m)";

    private static IReadOnlyList<Guid> ReadGuidColumn(JsonElement rows, string property)
    {
        var ids = new HashSet<Guid>();
        foreach (var row in rows.EnumerateArray())
        {
            if (row.ValueKind == JsonValueKind.Object &&
                row.TryGetProperty(property, out var value) &&
                value.ValueKind == JsonValueKind.String &&
                Guid.TryParse(value.GetString(), out var id) &&
                id != Guid.Empty)
                ids.Add(id);
        }

        return ids.ToArray();
    }

    private static JsonElement ToJsonArray(IReadOnlyCollection<JsonElement> rows)
    {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream))
        {
            writer.WriteStartArray();
            foreach (var row in rows)
                row.WriteTo(writer);
            writer.WriteEndArray();
        }

        using var document = JsonDocument.Parse(stream.ToArray());
        return document.RootElement.Clone();
    }
}

public static class StationDirectoryVisibility
{
    private static readonly string[] StationReadPermissions =
    [
        "observation.create",
        "observation.review",
        "observation.approve",
        "observation.return_for_correction",
        "users.station.manage"
    ];

    private static readonly string[] AuthorityReadPermissions =
    [
        "stations.catalogue.review",
        "registrations.system.approve"
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

        foreach (var permission in AuthorityReadPermissions)
        {
            if (await authorization.HasStationOwnerAuthorityPermissionAsync(
                    userId, stationId, permission, cancellationToken))
                return true;
        }

        return false;
    }

    public static async Task<bool> CanViewAuthorityAsync(
        IStationAuthorizationService authorization,
        Guid userId,
        Guid authorityId,
        CancellationToken cancellationToken)
    {
        if (!authorization.IsConfigured || userId == Guid.Empty || authorityId == Guid.Empty)
            return false;

        foreach (var permission in AuthorityReadPermissions)
        {
            if (await authorization.HasAuthorityPermissionAsync(
                    userId, authorityId, permission, cancellationToken))
                return true;
        }

        return false;
    }
}

public static class StationDirectoryEndpoints
{
    private const int MaximumCandidates = 10_000;

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

            var assignedStationIds = await directory.GetAssignedStationIdsAsync(userId, cancellationToken);
            var membershipAuthorityIds = await directory.GetAuthorityIdsAsync(userId, cancellationToken);
            if (assignedStationIds is null || membershipAuthorityIds is null)
                return Results.Problem(
                    title: "Station scope could not be resolved",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            var authorizedAuthorityIds = new HashSet<Guid>();
            foreach (var authorityId in membershipAuthorityIds)
            {
                if (await StationDirectoryVisibility.CanViewAuthorityAsync(
                        authorization, userId, authorityId, cancellationToken))
                    authorizedAuthorityIds.Add(authorityId);
            }

            var candidateStations = await directory.GetStationsByScopeAsync(
                assignedStationIds,
                authorizedAuthorityIds,
                stationType,
                cancellationToken);
            if (candidateStations is null || candidateStations.Value.ValueKind != JsonValueKind.Array)
                return Results.Problem(
                    title: "Station directory read failed",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            var rows = candidateStations.Value.EnumerateArray()
                .Select(row => row.Clone())
                .Take(MaximumCandidates + 1)
                .ToArray();
            if (rows.Length > MaximumCandidates)
                return Results.Problem(
                    title: "Authorized station scope exceeds the safe directory limit",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            var visible = new bool[rows.Length];
            await Parallel.ForEachAsync(
                Enumerable.Range(0, rows.Length),
                new ParallelOptions
                {
                    MaxDegreeOfParallelism = 8,
                    CancellationToken = cancellationToken
                },
                async (index, token) =>
                {
                    var row = rows[index];
                    if (!row.TryGetProperty("id", out var idValue) ||
                        idValue.ValueKind != JsonValueKind.String ||
                        !Guid.TryParse(idValue.GetString(), out var stationId) ||
                        stationId == Guid.Empty)
                        return;

                    if (row.TryGetProperty("owner_authority_id", out var authorityValue) &&
                        authorityValue.ValueKind == JsonValueKind.String &&
                        Guid.TryParse(authorityValue.GetString(), out var authorityId) &&
                        authorizedAuthorityIds.Contains(authorityId))
                    {
                        visible[index] = true;
                        return;
                    }

                    visible[index] = await StationDirectoryVisibility.CanViewAsync(
                        authorization, userId, stationId, token);
                });

            var result = rows.Where((_, index) => visible[index])
                .Skip(skip)
                .Take(take)
                .ToArray();
            return Results.Ok(result);
        })
        .WithTags("Stations")
        .WithName("GetStationDirectory");

        return endpoints;
    }
}
