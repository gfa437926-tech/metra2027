using System.Net;
using System.Text;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class LegacyHs256AuthenticationTests
{
    private static readonly Guid UserId = Guid.Parse("11111111-2222-3333-4444-555555555555");
    private const string SupabaseUrl = "https://tbdnklyxjvbrilvnwgmq.supabase.co";
    private const string PublishableKey = "sb_publishable_test_only";

    [Fact]
    public async Task Valid_legacy_HS256_token_is_verified_by_the_fixed_Supabase_Auth_user_endpoint()
    {
        var handler = new StubHandler(HttpStatusCode.OK, $$"""{"id":"{{UserId}}","email":"observer@example.test"}""");
        using var factory = CreateFactory(handler);
        using var client = factory.CreateClient();
        var token = CreateToken("HS256", UserId, SupabaseUrl + "/auth/v1", "authenticated");

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/stations");
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        using var response = await client.SendAsync(request);

        Assert.NotEqual(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal(1, handler.CallCount);
        Assert.Equal(new Uri(SupabaseUrl + "/auth/v1/user"), handler.RequestUri);
        Assert.Equal(PublishableKey, handler.ApiKey);
        Assert.Equal("Bearer " + token, handler.Authorization);
    }

    [Fact]
    public async Task Supabase_Auth_rejection_fails_closed()
    {
        var handler = new StubHandler(HttpStatusCode.Unauthorized, "{}");
        using var factory = CreateFactory(handler);
        using var client = factory.CreateClient();
        var token = CreateToken("HS256", UserId, SupabaseUrl + "/auth/v1", "authenticated");

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/stations");
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        using var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal(1, handler.CallCount);
    }

    [Theory]
    [InlineData("https://attacker.invalid/auth/v1", "authenticated")]
    [InlineData("https://tbdnklyxjvbrilvnwgmq.supabase.co/auth/v1", "other-audience")]
    public async Task Verified_token_still_must_match_configured_issuer_and_audience(
        string issuer, string audience)
    {
        var handler = new StubHandler(HttpStatusCode.OK, $$"""{"id":"{{UserId}}"}""");
        using var factory = CreateFactory(handler);
        using var client = factory.CreateClient();
        var token = CreateToken("HS256", UserId, issuer, audience);

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/stations");
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        using var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Auth_response_user_id_must_match_the_signed_subject()
    {
        var handler = new StubHandler(HttpStatusCode.OK, """{"id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"}""");
        using var factory = CreateFactory(handler);
        using var client = factory.CreateClient();
        var token = CreateToken("HS256", UserId, SupabaseUrl + "/auth/v1", "authenticated");

        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/stations");
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        using var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ES256_token_remains_on_the_local_JWKS_validation_path()
    {
        using var ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        var signingKey = new ECDsaSecurityKey(ecdsa);
        var issuer = SupabaseUrl + "/auth/v1";
        var now = DateTime.UtcNow;
        var jwt = new JwtSecurityToken(
            issuer,
            "authenticated",
            new[] { new Claim("sub", UserId.ToString()) },
            now.AddMinutes(-1),
            now.AddMinutes(5),
            new SigningCredentials(signingKey, SecurityAlgorithms.EcdsaSha256));
        var token = new JwtSecurityTokenHandler().WriteToken(jwt);

        using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, configuration) =>
                configuration.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Supabase:Url"] = SupabaseUrl,
                    ["Authentication:Authority"] = issuer,
                    ["Authentication:Audience"] = "authenticated"
                }));
            builder.ConfigureTestServices(services =>
                services.PostConfigure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, options =>
                {
                    options.Authority = null;
                    options.Audience = null;
                    options.ConfigurationManager = null;
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidIssuer = issuer,
                        ValidateAudience = true,
                        ValidAudience = "authenticated",
                        ValidateLifetime = true,
                        ValidateIssuerSigningKey = true,
                        IssuerSigningKey = signingKey,
                        ClockSkew = TimeSpan.FromSeconds(60)
                    };
                }));
        });
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/stations");
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);

        using var response = await client.SendAsync(request);

        Assert.NotEqual(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    private static WebApplicationFactory<Program> CreateFactory(StubHandler handler) =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, configuration) =>
                configuration.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Supabase:Url"] = SupabaseUrl,
                    ["Supabase:PublishableKey"] = PublishableKey,
                    ["Authentication:Authority"] = SupabaseUrl + "/auth/v1",
                    ["Authentication:Audience"] = "authenticated"
                }));
            builder.ConfigureTestServices(services =>
                services.AddHttpClient(SupabaseLegacyHs256AuthenticationHandler.HttpClientName)
                    .ConfigurePrimaryHttpMessageHandler(() => handler));
        });

    private static string CreateToken(string algorithm, Guid subject, string issuer, string audience)
    {
        static string Encode(string value) =>
            Microsoft.IdentityModel.Tokens.Base64UrlEncoder.Encode(Encoding.UTF8.GetBytes(value));

        var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var header = Encode($$"""{"alg":"{{algorithm}}","typ":"JWT"}""");
        var payload = Encode($$"""{"iss":"{{issuer}}","aud":"{{audience}}","sub":"{{subject}}","iat":{{now}},"nbf":{{now - 5}},"exp":{{now + 300}}}""");
        return header + "." + payload + ".mock-signature";
    }

    private sealed class StubHandler(HttpStatusCode statusCode, string body) : HttpMessageHandler
    {
        public int CallCount { get; private set; }
        public Uri? RequestUri { get; private set; }
        public string? ApiKey { get; private set; }
        public string? Authorization { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            CallCount++;
            RequestUri = request.RequestUri;
            ApiKey = request.Headers.TryGetValues("apikey", out var values) ? values.Single() : null;
            Authorization = request.Headers.Authorization?.ToString();
            return Task.FromResult(new HttpResponseMessage(statusCode)
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json")
            });
        }
    }
}
