using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Users;

public interface IStationAuditService
{
    bool IsConfigured { get; }
    Task<JsonElement?> GetAuditAsync(Guid stationId, int limit, CancellationToken cancellationToken);
}

public sealed class SupabaseStationAuditService(
    IHttpClientFactory clients, IConfiguration configuration) : IStationAuditService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    public async Task<JsonElement?> GetAuditAsync(Guid stationId, int limit, CancellationToken cancellationToken)
    {
        if (!IsConfigured || stationId == Guid.Empty || limit is < 1 or > 250) return null;

        using var message = new HttpRequestMessage(
            HttpMethod.Post, $"{_url!.TrimEnd('/')}/rest/v1/rpc/get_station_audit_log");
        message.Headers.TryAddWithoutValidation("apikey", _key);
        message.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
        message.Content = JsonContent.Create(new { p_station_id = stationId, p_limit = limit });

        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseStationAuditService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode) return null;
            return await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: cancellationToken);
        }
        catch (HttpRequestException) { return null; }
        catch (JsonException) { return null; }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested) { return null; }
    }
}

public static class StationAuditEndpoints
{
    public static IEndpointRouteBuilder MapStationAuditEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/stations/{stationId:guid}/audit-log", async (
            Guid stationId, int? limit, IStationAuditService audit, CancellationToken cancellationToken) =>
        {
            var take = limit ?? 100;
            var validationError = StationAuditRequestGuard.GetError(stationId, take);
            if (validationError == "invalid_station_id")
                return Results.BadRequest(new { error = validationError });
            if (validationError == "invalid_limit")
                return Results.BadRequest(new { error = validationError, maximum = 250 });
            if (!audit.IsConfigured)
                return Results.Problem(title: "Station audit service unavailable", statusCode: 503);

            var events = await audit.GetAuditAsync(stationId, take, cancellationToken);
            return events is null
                ? Results.Problem(title: "Station audit read failed", statusCode: 503)
                : Results.Ok(events.Value);
        })
        .RequireStationPermission("users.station.view")
        .WithTags("Users")
        .WithName("GetStationAuditLog");

        return endpoints;
    }
}

public static class StationAuditRequestGuard
{
    public static string? GetError(Guid stationId, int limit)
    {
        if (stationId == Guid.Empty) return "invalid_station_id";
        if (limit is < 1 or > 250) return "invalid_limit";
        return null;
    }
}
