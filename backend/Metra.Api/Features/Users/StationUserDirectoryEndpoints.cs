using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Users;

public interface IStationUserDirectoryService
{
    bool IsConfigured { get; }
    Task<JsonElement?> GetUsersAsync(Guid actorUserId, Guid stationId, int limit, CancellationToken cancellationToken);
}

public sealed class SupabaseStationUserDirectoryService(
    IHttpClientFactory clients, IConfiguration configuration) : IStationUserDirectoryService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps && !string.IsNullOrWhiteSpace(_key);

    public async Task<JsonElement?> GetUsersAsync(
        Guid actorUserId, Guid stationId, int limit, CancellationToken cancellationToken)
    {
        if (!IsConfigured || actorUserId == Guid.Empty || stationId == Guid.Empty || limit is < 1 or > 500)
            return null;

        using var request = new HttpRequestMessage(
            HttpMethod.Post, $"{_url!.TrimEnd('/')}/rest/v1/rpc/get_station_user_directory_atomic");
        request.Headers.TryAddWithoutValidation("apikey", _key);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
        request.Content = JsonContent.Create(new {
            p_actor_user_id = actorUserId, p_station_id = stationId, p_limit = limit
        });

        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseStationUserDirectoryService))
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

public static class StationUserDirectoryEndpoints
{
    public static IEndpointRouteBuilder MapStationUserDirectoryEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/stations/{stationId:guid}/users", async (
            Guid stationId, int? limit, HttpContext http,
            IStationUserDirectoryService directory, CancellationToken cancellationToken) =>
        {
            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorUserId))
                return Results.Unauthorized();
            var take = limit ?? 250;
            if (take is < 1 or > 500)
                return Results.BadRequest(new { error = "invalid_limit", maximum = 500 });
            if (!directory.IsConfigured)
                return Results.Problem(title: "Station user directory unavailable", statusCode: 503);
            JsonElement? users;
            try { users = await directory.GetUsersAsync(actorUserId, stationId, take, cancellationToken); }
            catch (StationReadForbiddenException)
            {
                return Results.Json(new { code = "station_permission_denied" }, statusCode: 403);
            }
            return users is null
                ? Results.Problem(title: "Station user directory read failed", statusCode: 503)
                : Results.Ok(users.Value);
        })
        .WithTags("Users")
        .RequireAuthorization()
        .RequireRateLimiting(MetraRateLimiting.PolicyRead)
        .WithName("GetStationUsers");
        return endpoints;
    }
}
