using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Users;

public interface IStationUserDirectoryService
{
    bool IsConfigured { get; }
    Task<JsonElement?> GetUsersAsync(Guid stationId, int limit, CancellationToken cancellationToken);
}

public sealed class SupabaseStationUserDirectoryService(
    IHttpClientFactory clients, IConfiguration configuration) : IStationUserDirectoryService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public async Task<JsonElement?> GetUsersAsync(Guid stationId, int limit, CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || limit is < 1 or > 500) return null;
        using var message = new HttpRequestMessage(
            HttpMethod.Post, $"{_url!.TrimEnd('/')}/rest/v1/rpc/get_station_user_directory");
        message.Headers.TryAddWithoutValidation("apikey", _key);
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
        message.Content = JsonContent.Create(new { p_station_id = stationId, p_limit = limit });
        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseStationUserDirectoryService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode) return null;
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
            Guid stationId, int? limit, IStationUserDirectoryService directory, CancellationToken cancellationToken) =>
        {
            var take = limit ?? 250;
            if (take is < 1 or > 500)
                return Results.BadRequest(new { error = "invalid_limit", maximum = 500 });
            if (!directory.IsConfigured)
                return Results.Problem(title: "Station user directory unavailable", statusCode: 503);
            var users = await directory.GetUsersAsync(stationId, take, cancellationToken);
            return users is null
                ? Results.Problem(title: "Station user directory read failed", statusCode: 503)
                : Results.Ok(users.Value);
        })
        .RequireStationPermission("users.station.view")
        .WithTags("Users")
        .WithName("GetStationUsers");

        return endpoints;
    }
}
