using System.Net;
using System.Text;
using Metra.Api.Security;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class SupabaseAccessTokenValidatorTests
{
    [Fact]
    public async Task Returns_null_when_supabase_url_missing()
    {
        var validator = new SupabaseAccessTokenValidator(
            new FixedHttpClientFactory(_ => new HttpResponseMessage(HttpStatusCode.OK)),
            new ConfigurationBuilder().Build());

        var principal = await validator.ValidateAsync("token", CancellationToken.None);
        Assert.Null(principal);
    }

    [Fact]
    public async Task Returns_principal_with_sub_from_auth_user_payload()
    {
        var userId = Guid.NewGuid();
        var json = $"{{\"id\":\"{userId}\",\"email\":\"observer@example.test\",\"role\":\"authenticated\"}}";
        var validator = new SupabaseAccessTokenValidator(
            new FixedHttpClientFactory(_ => new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            }),
            new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:AnonKey"] = "anon-test"
            }).Build());

        var principal = await validator.ValidateAsync("access-token", CancellationToken.None);
        Assert.NotNull(principal);
        Assert.Equal(userId.ToString(), principal!.FindFirst("sub")?.Value);
        Assert.Equal("observer@example.test", principal.FindFirst("email")?.Value);
    }

    [Fact]
    public async Task Returns_null_on_unauthorized_auth_response()
    {
        var validator = new SupabaseAccessTokenValidator(
            new FixedHttpClientFactory(_ => new HttpResponseMessage(HttpStatusCode.Unauthorized)),
            new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:AnonKey"] = "anon-test"
            }).Build());

        var principal = await validator.ValidateAsync("bad-token", CancellationToken.None);
        Assert.Null(principal);
    }

    [Fact]
    public async Task Returns_null_when_payload_id_is_not_guid()
    {
        var validator = new SupabaseAccessTokenValidator(
            new FixedHttpClientFactory(_ => new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{\"id\":\"not-a-guid\"}", Encoding.UTF8, "application/json")
            }),
            new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:AnonKey"] = "anon-test"
            }).Build());

        var principal = await validator.ValidateAsync("token", CancellationToken.None);
        Assert.Null(principal);
    }

    private sealed class FixedHttpClientFactory(Func<HttpRequestMessage, HttpResponseMessage> handler)
        : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) =>
            new(new DelegateHandler(handler)) { Timeout = TimeSpan.FromSeconds(5) };
    }

    private sealed class DelegateHandler(Func<HttpRequestMessage, HttpResponseMessage> handler) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(handler(request));
    }
}
