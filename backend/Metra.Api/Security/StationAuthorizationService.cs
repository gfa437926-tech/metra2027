using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Metra.Api.Security;

public interface IStationAuthorizationService
{
    bool IsConfigured { get; }
    Task<bool> HasStationPermissionAsync(Guid userId, Guid stationId, string permissionCode, CancellationToken cancellationToken = default);
}

/// <summary>
/// Calls a narrowly scoped, server-only Supabase RPC. The service-role key
/// must be injected by the hosting secret manager and must never reach clients.
/// </summary>
public sealed class SupabaseStationAuthorizationService(
    IHttpClientFactory httpClientFactory,
    IConfiguration configuration) : IStationAuthorizationService
{
    private readonly string? _supabaseUrl = configuration["Supabase:Url"];
    private readonly string? _serviceKey = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_supabaseUrl, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_serviceKey);

    public async Task<bool> HasStationPermissionAsync(
        Guid userId,
        Guid stationId,
        string permissionCode,
        CancellationToken cancellationToken = default)
    {
        if (!IsConfigured || userId == Guid.Empty || stationId == Guid.Empty ||
            string.IsNullOrWhiteSpace(permissionCode))
            return false;

        var client = httpClientFactory.CreateClient(nameof(SupabaseStationAuthorizationService));
        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"{_supabaseUrl!.TrimEnd('/')}/rest/v1/rpc/metra_user_has_station_permission");

        request.Headers.TryAddWithoutValidation("apikey", _serviceKey);
        request.Headers.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _serviceKey);
        request.Content = JsonContent.Create(new
        {
            p_user_id = userId,
            p_station_id = stationId,
            p_permission_code = permissionCode
        });

        using var response = await client.SendAsync(request, cancellationToken);
        if (!response.IsSuccessStatusCode)
            return false;

        return await response.Content.ReadFromJsonAsync<bool>(cancellationToken: cancellationToken);
    }
}
