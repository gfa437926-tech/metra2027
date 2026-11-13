using System.Net;
using System.Text.Json;

namespace Metra.Api.Security;

public sealed class StationReadForbiddenException : Exception
{
    public StationReadForbiddenException() : base("Station-scoped read permission denied.") { }
}

public static class SupabaseRpcErrorHandling
{
    public static async Task<bool> IsPermissionDeniedAsync(
        HttpResponseMessage response,
        CancellationToken cancellationToken)
    {
        if (response.StatusCode == HttpStatusCode.Forbidden)
            return true;

        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        try
        {
            using var document = JsonDocument.Parse(body);
            return document.RootElement.TryGetProperty("code", out var code) &&
                code.ValueKind == JsonValueKind.String &&
                code.GetString() == "42501";
        }
        catch (JsonException)
        {
            return false;
        }
    }
}
