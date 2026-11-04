using System.Net;
using Metra.Api.Security;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class SupabaseStationAuthorizationServiceTests
{
    [Fact]
    public async Task Missing_server_key_disables_authorization()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co"
            })
            .Build();
        var service = new SupabaseStationAuthorizationService(
            new StubHttpClientFactory(new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("true")
            })),
            configuration);

        Assert.False(service.IsConfigured);
        Assert.False(await service.HasStationPermissionAsync(Guid.NewGuid(), Guid.NewGuid(), "observation.create"));
    }

    [Theory]
    [InlineData(HttpStatusCode.Forbidden, "false")]
    [InlineData(HttpStatusCode.InternalServerError, "false")]
    [InlineData(HttpStatusCode.OK, "not-json")]
    public async Task Authorization_fails_closed_for_errors_and_malformed_rpc_responses(
        HttpStatusCode statusCode,
        string body)
    {
        var service = CreateService(_ => new HttpResponseMessage(statusCode)
        {
            Content = new StringContent(body)
        });

        Assert.True(service.IsConfigured);
        Assert.False(await service.HasStationPermissionAsync(Guid.NewGuid(), Guid.NewGuid(), "observation.create"));
    }

    [Fact]
    public async Task Explicit_true_from_permission_rpc_is_accepted()
    {
        var service = CreateService(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent("true", System.Text.Encoding.UTF8, "application/json")
        });

        Assert.True(await service.HasStationPermissionAsync(Guid.NewGuid(), Guid.NewGuid(), "observation.create"));
    }

    [Fact]
    public async Task Authority_permission_uses_the_station_owner_authority_rpc()
    {
        var service = CreateService(request =>
        {
            Assert.Equal(
                "/rest/v1/rpc/metra_user_has_station_owner_authority_permission",
                request.RequestUri!.AbsolutePath);
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("true", System.Text.Encoding.UTF8, "application/json")
            };
        });

        Assert.True(await service.HasStationOwnerAuthorityPermissionAsync(
            Guid.NewGuid(), Guid.NewGuid(), "stations.catalogue.review"));
    }

    [Fact]
    public async Task Authority_permission_fails_closed_for_empty_identity_or_station()
    {
        var service = CreateService(_ => throw new InvalidOperationException("RPC must not be called"));

        Assert.False(await service.HasStationOwnerAuthorityPermissionAsync(
            Guid.Empty, Guid.NewGuid(), "stations.catalogue.review"));
        Assert.False(await service.HasStationOwnerAuthorityPermissionAsync(
            Guid.NewGuid(), Guid.Empty, "stations.catalogue.review"));
    }

    private static SupabaseStationAuthorizationService CreateService(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:ServiceRoleKey"] = "server-only-test-key"
            })
            .Build();

        return new SupabaseStationAuthorizationService(
            new StubHttpClientFactory(new StubHandler(responseFactory)),
            configuration);
    }

    private sealed class StubHttpClientFactory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
    }

    private sealed class StubHandler(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
            => Task.FromResult(responseFactory(request));
    }
}
