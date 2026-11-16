using System.Net;
using System.Text.Json;
using Metra.Api.Features.Users;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Metra.Api.Tests.Features.Users;

public sealed class SupabaseAuthorityAccessServiceTests
{
    [Fact]
    public async Task Calls_the_requested_server_side_rpc_with_service_credentials()
    {
        HttpRequestMessage? captured = null;
        string? body = null;
        var service = Create(request =>
        {
            captured = request;
            body = request.Content!.ReadAsStringAsync().GetAwaiter().GetResult();
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("\"committed\"", System.Text.Encoding.UTF8, "application/json")
            };
        });

        var result = await service.CallAsync("decide_authority_membership",
            new { p_membership_id = Guid.NewGuid(), p_actor_user_id = Guid.NewGuid(),
                p_decision = "approve", p_reason = "verified reviewer decision" }, CancellationToken.None);

        Assert.True(result.IsConfigured);
        Assert.True(result.Succeeded);
        Assert.NotNull(captured);
        Assert.Equal("/rest/v1/rpc/decide_authority_membership", captured.RequestUri!.AbsolutePath);
        Assert.Equal("Bearer", captured.Headers.Authorization!.Scheme);
        using var json = JsonDocument.Parse(body!);
        Assert.Equal("approve", json.RootElement.GetProperty("p_decision").GetString());
    }

    [Fact]
    public async Task Invalid_rpc_name_fails_closed_without_http_call()
    {
        var service = Create(_ => throw new InvalidOperationException("HTTP must not be called"));
        var result = await service.CallAsync("rpc/unsafe", new { }, CancellationToken.None);
        Assert.False(result.IsConfigured);
        Assert.False(result.Succeeded);
    }


        [Fact]
    public async Task Maps_unique_violation_body_to_conflict_even_when_http_500()
    {
        var service = Create(_ => new HttpResponseMessage(HttpStatusCode.InternalServerError)
        {
            Content = new StringContent(
                "{\"code\":\"23505\",\"message\":\"duplicate key value violates unique constraint permission_grants_active_station_unique\"}",
                System.Text.Encoding.UTF8, "application/json")
        });
        var result = await service.CallAsync("decide_authority_permission_grant",
            new { p_grant_id = Guid.NewGuid(), p_actor_user_id = Guid.NewGuid(),
                p_decision = "approve", p_reason = "approve concurrent active grant" }, CancellationToken.None);
        Assert.True(result.IsConfigured);
        Assert.False(result.Succeeded);
        Assert.Equal(HttpStatusCode.Conflict, result.StatusCode);
        Assert.Equal(AuthorityAccessConflictDetector.UniqueViolationKind, result.ErrorKind);
    }

    [Fact]
    public async Task Does_not_map_permission_denied_to_conflict()
    {
        var service = Create(_ => new HttpResponseMessage(HttpStatusCode.Forbidden)
        {
            Content = new StringContent(
                "{\"code\":\"42501\",\"message\":\"permission denied\"}",
                System.Text.Encoding.UTF8, "application/json")
        });
        var result = await service.CallAsync("request_authority_permission_grant",
            new { p_user_id = Guid.NewGuid() }, CancellationToken.None);
        Assert.True(result.IsConfigured);
        Assert.False(result.Succeeded);
        Assert.Equal(HttpStatusCode.Forbidden, result.StatusCode);
        Assert.Null(result.ErrorKind);
    }

    private static SupabaseAuthorityAccessService Create(Func<HttpRequestMessage, HttpResponseMessage> response)
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Supabase:Url"] = "https://example.supabase.co",
            ["Supabase:ServiceRoleKey"] = "server-only-test-key"
        }).Build();
        return new SupabaseAuthorityAccessService(new Factory(new Handler(response)), config);
    }

    private sealed class Factory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
    }

    private sealed class Handler(Func<HttpRequestMessage, HttpResponseMessage> response) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
            => Task.FromResult(response(request));
    }
}
