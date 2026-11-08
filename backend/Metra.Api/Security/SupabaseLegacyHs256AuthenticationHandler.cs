using System.IdentityModel.Tokens.Jwt;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System.Text.Encodings.Web;

namespace Metra.Api.Security;

/// <summary>
/// Validates legacy HS256 Supabase access tokens through the configured Auth /user
/// endpoint. The HS256 signing secret never leaves Supabase Auth.
/// </summary>
public sealed class SupabaseLegacyHs256AuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    IHttpClientFactory httpClientFactory,
    IConfiguration configuration)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "SupabaseLegacyHS256";
    public const string HttpClientName = "SupabaseLegacyHs256AuthVerifier";
    private static readonly SemaphoreSlim VerificationSlots = new(32, 32);
    private static readonly TimeSpan QueueAndRequestLimit = TimeSpan.FromSeconds(8);
    private readonly string? _supabaseUrl = configuration["Supabase:Url"]
        ?? "https://tbdnklyxjvbrilvnwgmq.supabase.co";
    private readonly string? _publishableKey = configuration["Supabase:PublishableKey"]
        ?? configuration["Supabase:AnonKey"];
    private readonly string _issuer = configuration["Authentication:Authority"]
        ?? $"{(configuration["Supabase:Url"] ?? "https://tbdnklyxjvbrilvnwgmq.supabase.co").TrimEnd('/')}/auth/v1";
    private readonly string _audience = configuration["Authentication:Audience"] ?? "authenticated";

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var authorization = Request.Headers.Authorization.ToString();
        if (!authorization.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            return AuthenticateResult.NoResult();

        var token = authorization["Bearer ".Length..].Trim();
        if (!TryReadAlgorithm(token, out var algorithm) ||
            !string.Equals(algorithm, "HS256", StringComparison.Ordinal))
            return AuthenticateResult.Fail("Unsupported legacy token.");

        if (!Uri.TryCreate(_supabaseUrl, UriKind.Absolute, out var baseUri) ||
            baseUri.Scheme != Uri.UriSchemeHttps ||
            string.IsNullOrWhiteSpace(_publishableKey))
            return AuthenticateResult.Fail("Legacy token verification is not configured.");

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(Context.RequestAborted);
        timeout.CancelAfter(QueueAndRequestLimit);
        var entered = false;
        try
        {
            await VerificationSlots.WaitAsync(timeout.Token);
            entered = true;

            using var request = new HttpRequestMessage(
                HttpMethod.Get, new Uri(baseUri, "/auth/v1/user"));
            request.Headers.TryAddWithoutValidation("apikey", _publishableKey);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

            var client = httpClientFactory.CreateClient(HttpClientName);
            using var response = await client.SendAsync(
                request, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
            if (!response.IsSuccessStatusCode)
                return AuthenticateResult.Fail("Legacy token verification failed.");

            await using var stream = await response.Content.ReadAsStreamAsync(timeout.Token);
            using var user = await JsonDocument.ParseAsync(stream, cancellationToken: timeout.Token);
            if (!user.RootElement.TryGetProperty("id", out var idElement) ||
                !Guid.TryParse(idElement.GetString(), out var userId) ||
                userId == Guid.Empty)
                return AuthenticateResult.Fail("Verified Auth response has no valid user id.");

            // Auth /user has already verified the signature and token activity.
            // Only after that succeeds do we inspect signed claims for issuer/audience
            // parity with the ES256 JwtBearer configuration.
            if (!TryValidateVerifiedClaims(token, userId, out var payload))
                return AuthenticateResult.Fail("Legacy token claims are invalid.");

            var claims = new List<Claim> { new("sub", userId.ToString()) };
            if (user.RootElement.TryGetProperty("email", out var email) &&
                email.ValueKind == JsonValueKind.String &&
                !string.IsNullOrWhiteSpace(email.GetString()))
                claims.Add(new Claim(ClaimTypes.Email, email.GetString()!));

            var identity = new ClaimsIdentity(claims, Scheme.Name, ClaimTypes.Name, ClaimTypes.Role);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme.Name);
            return AuthenticateResult.Success(ticket);
        }
        catch (OperationCanceledException) when (Context.RequestAborted.IsCancellationRequested)
        {
            throw;
        }
        catch (OperationCanceledException)
        {
            return AuthenticateResult.Fail("Legacy token verification timed out.");
        }
        catch (HttpRequestException)
        {
            return AuthenticateResult.Fail("Legacy token verification is unavailable.");
        }
        catch (JsonException)
        {
            return AuthenticateResult.Fail("Legacy token verification returned an invalid response.");
        }
        catch (Exception)
        {
            // Never include request headers or token data in failure messages.
            return AuthenticateResult.Fail("Legacy token verification failed.");
        }
        finally
        {
            if (entered)
                VerificationSlots.Release();
        }
    }

    public static bool TryReadAlgorithm(string token, out string? algorithm)
    {
        algorithm = null;
        var parts = token.Split('.');
        if (parts.Length != 3 || parts.Any(string.IsNullOrWhiteSpace))
            return false;

        try
        {
            using var header = JsonDocument.Parse(Base64UrlEncoder.DecodeBytes(parts[0]));
            if (!header.RootElement.TryGetProperty("alg", out var value) ||
                value.ValueKind != JsonValueKind.String)
                return false;
            algorithm = value.GetString();
            return !string.IsNullOrWhiteSpace(algorithm);
        }
        catch (Exception)
        {
            return false;
        }
    }

    private bool TryValidateVerifiedClaims(string token, Guid authUserId, out JwtPayload payload)
    {
        payload = new JwtPayload();
        try
        {
            var jwt = new JwtSecurityTokenHandler().ReadJwtToken(token);
            if (!string.Equals(jwt.Issuer, _issuer, StringComparison.Ordinal) ||
                !jwt.Audiences.Contains(_audience, StringComparer.Ordinal) ||
                !Guid.TryParse(jwt.Subject, out var subject) ||
                subject != authUserId)
                return false;

            var now = DateTimeOffset.UtcNow;
            var skew = TimeSpan.FromSeconds(60);
            if (jwt.ValidTo == DateTime.MinValue || now - skew >= jwt.ValidTo)
                return false;
            if (jwt.Payload.Nbf is long notBefore &&
                now + skew < DateTimeOffset.FromUnixTimeSeconds(notBefore))
                return false;

            payload = jwt.Payload;
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }
}
