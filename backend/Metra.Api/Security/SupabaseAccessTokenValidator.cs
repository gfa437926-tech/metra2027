using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text.Json;

namespace Metra.Api.Security;

/// <summary>
/// Secondary token check against Supabase Auth user endpoint (HS256-era tokens and
/// live session confirmation). Does not trust client-supplied claims; identity is
/// taken only from a successful Auth response.
/// </summary>
public interface ISupabaseAccessTokenValidator
{
    Task<ClaimsPrincipal?> ValidateAsync(string accessToken, CancellationToken cancellationToken);
}

public sealed class SupabaseAccessTokenValidator(
    IHttpClientFactory httpClientFactory,
    IConfiguration configuration) : ISupabaseAccessTokenValidator
{
    private readonly string? _supabaseUrl = configuration["Supabase:Url"];
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public bool IsConfigured =>
        Uri.TryCreate(_supabaseUrl, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps;

    public async Task<ClaimsPrincipal?> ValidateAsync(
        string accessToken,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(accessToken))
            return null;

        using var request = new HttpRequestMessage(
            HttpMethod.Get,
            $"{_supabaseUrl!.TrimEnd('/')}/auth/v1/user");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        // anon key is required by Supabase gateway for /auth/v1/user; never use service role here.
        var anonKey = configuration["Supabase:AnonKey"]
            ?? configuration["Supabase:PublishableKey"];
        if (string.IsNullOrWhiteSpace(anonKey))
            return null;
        request.Headers.TryAddWithoutValidation("apikey", anonKey);

        try
        {
            using var response = await httpClientFactory
                .CreateClient(nameof(SupabaseAccessTokenValidator))
                .SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return null;

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            if (!document.RootElement.TryGetProperty("id", out var idElement))
                return null;

            var userId = idElement.GetString();
            if (string.IsNullOrWhiteSpace(userId) || !Guid.TryParse(userId, out _))
                return null;

            var claims = new List<Claim>
            {
                new("sub", userId),
                new(ClaimTypes.NameIdentifier, userId)
            };

            if (document.RootElement.TryGetProperty("email", out var emailElement) &&
                emailElement.GetString() is { Length: > 0 } email)
            {
                claims.Add(new Claim("email", email));
            }

            if (document.RootElement.TryGetProperty("role", out var roleElement) &&
                roleElement.GetString() is { Length: > 0 } role)
            {
                claims.Add(new Claim("role", role));
            }

            var identity = new ClaimsIdentity(claims, authenticationType: "SupabaseAccessToken");
            return new ClaimsPrincipal(identity);
        }
        catch (HttpRequestException)
        {
            return null;
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return null;
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
