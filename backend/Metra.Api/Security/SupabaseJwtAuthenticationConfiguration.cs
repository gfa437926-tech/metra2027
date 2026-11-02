using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

namespace Metra.Api.Security;

/// <summary>
/// Configures Supabase Auth JWT validation without trusting user-editable
/// metadata or token role claims for METRA permissions.
/// </summary>
public static class SupabaseJwtAuthenticationConfiguration
{
    public const string Scheme = JwtBearerDefaults.AuthenticationScheme;
    public const string AuthorityKey = "Authentication:Supabase:Authority";
    public const string AudienceKey = "Authentication:Supabase:Audience";

    public static IServiceCollection AddMetraConfiguredAuthentication(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        ArgumentNullException.ThrowIfNull(configuration);
        ArgumentNullException.ThrowIfNull(environment);

        var authority = configuration[AuthorityKey];
        var audience = configuration[AudienceKey];

        if (string.IsNullOrWhiteSpace(authority) || string.IsNullOrWhiteSpace(audience))
        {
            if (!environment.IsDevelopment())
            {
                throw new InvalidOperationException(
                    "Authentication:Supabase:Authority and Authentication:Supabase:Audience must be configured outside Development.");
            }

            // Local development remains deliberately closed until valid provider
            // settings are supplied. No development bypass or fake identity exists.
            return services.AddMetraAuthenticationBoundary();
        }

        var issuer = ValidateAuthority(authority);
        if (string.IsNullOrWhiteSpace(audience) ||
            audience.Length > 256 ||
            audience.Any(char.IsControl))
        {
            throw new InvalidOperationException(
                "Authentication:Supabase:Audience must be a non-empty, valid audience value.");
        }

        services.AddAuthentication(options =>
        {
            options.DefaultAuthenticateScheme = Scheme;
            options.DefaultChallengeScheme = Scheme;
            options.DefaultForbidScheme = Scheme;
        })
        .AddJwtBearer(Scheme, options =>
        {
            options.Authority = issuer;
            options.Audience = audience;
            options.RequireHttpsMetadata = true;
            options.SaveToken = false;
            options.MapInboundClaims = false;
            options.IncludeErrorDetails = environment.IsDevelopment();
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = issuer,
                ValidateAudience = true,
                ValidAudience = audience,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                NameClaimType = "sub",
                ClockSkew = TimeSpan.FromSeconds(60)
            };
        });

        return services;
    }

    private static string ValidateAuthority(string authority)
    {
        if (!Uri.TryCreate(authority, UriKind.Absolute, out var uri) ||
            uri.Scheme != Uri.UriSchemeHttps ||
            uri.UserInfo.Length != 0 ||
            !string.IsNullOrEmpty(uri.Query) ||
            !string.IsNullOrEmpty(uri.Fragment) ||
            uri.AbsolutePath == "/")
        {
            throw new InvalidOperationException(
                "Authentication:Supabase:Authority must be the HTTPS Supabase Auth issuer URL, including its issuer path and without credentials, query, or fragment.");
        }

        return uri.GetLeftPart(UriPartial.Path).TrimEnd('/');
    }
}
