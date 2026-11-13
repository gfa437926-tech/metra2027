using System.Net;
using System.Text.Json;

namespace Metra.Api.Security;

public sealed class StationReadForbiddenException : Exception
{
    public StationReadForbiddenException() : base("Station-scoped permission denied.") { }
}

public static class SupabaseRpcErrorHandling
{
    public static async Task<HttpStatusCode> MapDatabaseErrorStatusAsync(
        HttpResponseMessage response,
        CancellationToken cancellationToken)
    {
        if (response.StatusCode == HttpStatusCode.Forbidden)
            return HttpStatusCode.Forbidden;
        if (response.StatusCode == HttpStatusCode.Conflict)
            return HttpStatusCode.Conflict;

        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        try
        {
            using var document = JsonDocument.Parse(body);
            if (document.RootElement.TryGetProperty("code", out var code) &&
                code.ValueKind == JsonValueKind.String)
            {
                return code.GetString() switch
                {
                    "42501" => HttpStatusCode.Forbidden,
                    "23505" => HttpStatusCode.Conflict,
                    "P0002" => HttpStatusCode.NotFound,
                    "22023" => HttpStatusCode.BadRequest,
                    _ => response.StatusCode
                };
            }
        }
        catch (JsonException)
        {
            // Preserve the provider HTTP status for non-JSON errors.
        }
        return response.StatusCode;
    }

    public static async Task<bool> IsPermissionDeniedAsync(
        HttpResponseMessage response,
        CancellationToken cancellationToken) =>
        await MapDatabaseErrorStatusAsync(response, cancellationToken) == HttpStatusCode.Forbidden;
}
