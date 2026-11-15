using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Metra.Api.Domain.Stations;

namespace Metra.Api.Features.Stations;

/// <summary>
/// Calls one server-only, actor-bound database projection. The actor UUID must
/// come from the validated JWT subject in the HTTP layer; clients never supply it.
/// The service-role key is used only to execute this narrow RPC and never reaches a client.
/// </summary>
public interface IGreenfieldStationDirectoryReader
{
    bool IsConfigured { get; }
    Task<GreenfieldStationDirectoryResult?> GetStationsAsync(
        Guid validatedActorUserId,
        int limit,
        int offset,
        string? stationTypeCode,
        CancellationToken cancellationToken);
}

public sealed class SupabaseGreenfieldStationDirectoryReader(
    IHttpClientFactory clients,
    IConfiguration configuration) : IGreenfieldStationDirectoryReader
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _serviceRoleKey = configuration["Supabase:ServiceRoleKey"];
    private readonly bool _explicitlyEnabled =
        configuration.GetValue<bool>("Features:GreenfieldStationDirectoryEnabled");

    public bool IsConfigured =>
        _explicitlyEnabled &&
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_serviceRoleKey) &&
        !_serviceRoleKey.StartsWith("sb_publishable_", StringComparison.OrdinalIgnoreCase);

    public async Task<GreenfieldStationDirectoryResult?> GetStationsAsync(
        Guid validatedActorUserId,
        int limit,
        int offset,
        string? stationTypeCode,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || validatedActorUserId == Guid.Empty ||
            limit is < 1 or > GreenfieldStationDirectoryMapper.MaximumStations ||
            offset < 0 || (stationTypeCode is not null && !IsSafeTypeCode(stationTypeCode)))
            return null;

        using var request = new HttpRequestMessage(
            HttpMethod.Post, $"{_url!.TrimEnd('/')}/rest/v1/rpc/get_station_directory_for_actor");
        request.Headers.TryAddWithoutValidation("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Headers.TryAddWithoutValidation("Content-Profile", "catalog");
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        request.Content = JsonContent.Create(new
        {
            p_actor_user_id = validatedActorUserId,
            p_limit = limit,
            p_offset = offset,
            p_station_type_code = stationTypeCode
        });

        try
        {
            using var response = await clients
                .CreateClient(nameof(SupabaseGreenfieldStationDirectoryReader))
                .SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return null;

            var rows = await response.Content.ReadFromJsonAsync<JsonElement>(
                cancellationToken: cancellationToken);
            return rows.ValueKind == JsonValueKind.Array
                ? GreenfieldStationDirectoryMapper.Map(rows)
                : null;
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
        catch (InvalidOperationException)
        {
            return null;
        }
    }

    private static bool IsSafeTypeCode(string value) =>
        value.Length is > 0 and <= 64 &&
        value.All(character => char.IsAsciiLetterOrDigit(character) ||
            character is '_' or '-');
}
