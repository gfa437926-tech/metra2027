using System.Net.Http.Json;
using System.Text.Json;

namespace Metra.Api.Security;

public interface IStationAuthorizationService
{
    bool IsConfigured { get; }
    Task<bool> HasStationPermissionAsync(Guid userId, Guid stationId, string permissionCode, CancellationToken cancellationToken = default);
    Task<bool> HasStationOwnerAuthorityPermissionAsync(Guid userId, Guid stationId, string permissionCode, CancellationToken cancellationToken = default);
}

/// <summary>
/// Calls narrowly scoped, server-only Supabase authorization RPCs. The service-role key
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

    public Task<bool> HasStationPermissionAsync(
        Guid userId, Guid stationId, string permissionCode,
        CancellationToken cancellationToken = default) =>
        HasPermissionAsync(
            "metra_user_has_station_permission", userId, stationId, permissionCode, cancellationToken);

    public Task<bool> HasStationOwnerAuthorityPermissionAsync(
        Guid userId, Guid stationId, string permissionCode,
        CancellationToken cancellationToken = default) =>
        HasPermissionAsync(
            "metra_user_has_station_owner_authority_permission", userId, stationId, permissionCode, cancellationToken);

    private async Task<bool> HasPermissionAsync(
        string rpcName, Guid userId, Guid stationId, string permissionCode,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || userId == Guid.Empty || stationId == Guid.Empty ||
            string.IsNullOrWhiteSpace(permissionCode))
            return false;

        var client = httpClientFactory.CreateClient(nameof(SupabaseStationAuthorizationService));
        using var request = new HttpRequestMessage(
            HttpMethod.Post, $"{_supabaseUrl!.TrimEnd('/')}/rest/v1/rpc/{rpcName}");

        request.Headers.TryAddWithoutValidation("apikey", _serviceKey);
        request.Headers.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _serviceKey);
        request.Content = JsonContent.Create(new
        {
            p_user_id = userId,
            p_station_id = stationId,
            p_permission_code = permissionCode
        });

        try
        {
            using var response = await client.SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return false;

            // A malformed or empty RPC response must never authorize access.
            return await response.Content.ReadFromJsonAsync<bool>(cancellationToken: cancellationToken);
        }
        catch (JsonException)
        {
            return false;
        }
        catch (HttpRequestException)
        {
            return false;
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return false;
        }
    }
}
