using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

namespace Metra.Api.Security;

public static class MetraJwtBearerConfiguration
{
    /// <summary>
    /// Primary path: Authority metadata / JWKS (Supabase ES256 asymmetric keys).
    /// Secondary path: on signature/key failures, validate the bearer token via
    /// Supabase /auth/v1/user (covers transitional HS256 sessions without trusting
    /// client-supplied claims). Optional Authentication:JwtSecret enables local
    /// HS256 signature verification in parallel during key rotation.
    /// </summary>
    public static void Configure(
        JwtBearerOptions options,
        IConfiguration configuration,
        string authority,
        string audience)
    {
        options.Authority = authority;
        options.Audience = audience;
        options.RequireHttpsMetadata = true;
        options.MapInboundClaims = false;
        options.RefreshOnIssuerKeyNotFound = true;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = authority,
            ValidateAudience = true,
            ValidAudience = audience,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            NameClaimType = "sub",
            ClockSkew = TimeSpan.FromSeconds(30)
        };

        var jwtSecret = configuration["Authentication:JwtSecret"]
            ?? configuration["Supabase:JwtSecret"];
        if (!string.IsNullOrWhiteSpace(jwtSecret))
        {
            // Parallel HS256 key used by resolver without removing JWKS keys from metadata.
            var hsKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret));
            options.TokenValidationParameters.IssuerSigningKeyResolver =
                (token, securityToken, kid, validationParameters) =>
                {
                    var keys = new List<SecurityKey> { hsKey };
                    if (validationParameters.IssuerSigningKey is not null)
                        keys.Add(validationParameters.IssuerSigningKey);
                    if (validationParameters.IssuerSigningKeys is not null)
                        keys.AddRange(validationParameters.IssuerSigningKeys);
                    return keys;
                };
        }

        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = context =>
            {
                var sub = context.Principal?.FindFirst("sub")?.Value
                    ?? context.Principal?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
                if (string.IsNullOrWhiteSpace(sub) || !Guid.TryParse(sub, out var userId) || userId == Guid.Empty)
                    context.Fail("missing_or_invalid_sub_claim");
                return Task.CompletedTask;
            },
            OnAuthenticationFailed = async context =>
            {
                if (context.Exception is not SecurityTokenException)
                    return;

                var header = context.Request.Headers.Authorization.ToString();
                if (string.IsNullOrWhiteSpace(header) ||
                    !header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                    return;

                var raw = header["Bearer ".Length..].Trim();
                if (raw.Length == 0)
                    return;

                var validator = context.HttpContext.RequestServices
                    .GetService(typeof(ISupabaseAccessTokenValidator)) as ISupabaseAccessTokenValidator;
                if (validator is null)
                    return;

                var principal = await validator.ValidateAsync(raw, context.HttpContext.RequestAborted);
                if (principal is null)
                    return;

                context.Principal = principal;
                context.Success();
            }
        };
    }

    public const string Hs256ToEs256TransitionPlan =
        "1) Keep Authentication:JwtSecret server-side only during dual-sign window. " +
        "2) Enable Supabase JWKS (ES256). " +
        "3) Deploy API with Authority validation + optional HS256 secret + /auth/v1/user fallback. " +
        "4) Monitor failures by kid for one full access-token lifetime. " +
        "5) Remove JwtSecret after HS256 tokens expire. " +
        "6) Never ship JWT secrets to Angular/Flutter.";
}
