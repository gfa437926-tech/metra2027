using System.Net;
using System.Text;
using Microsoft.Extensions.Configuration;
using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests.Security;

public sealed class StationAuthorizationServiceTests
{
    [Fact]
    public async Task Permission_is_granted_only_when_rpc_returns_json_true()
    {
        var handler = new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent("true", Encoding.UTF8, "application/json")
        });
        var service = CreateService(handler);

        var allowed = await service.HasStationPermissionAsync(
            Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.create");

        Assert.True(allowed);
    }

    [Fact]
    public async Task Permission_check_sends_the_exact_user_station_and_permission_to_server_rpc()
    {
        var userId = Guid.Parse("11111111-1111-1111-1111-111111111111");
        var stationId = Guid.Parse("22222222-2222-2222-2222-222222222222");
        var handler = new StubHandler(request =>
        {
            Assert.Equal(HttpMethod.Post, request.Method);
            Assert.Equal(
                "https://example.supabase.co/rest/v1/rpc/metra_user_has_station_permission",
                request.RequestUri?.ToString());
            Assert.Equal("Bearer", request.Headers.Authorization?.Scheme);
            Assert.Equal("unit-test-secret", request.Headers.Authorization?.Parameter);
            var body = request.Content!.ReadAsStringAsync().GetAwaiter().GetResult();
            Assert.Contains(userId.ToString(), body, StringComparison.OrdinalIgnoreCase);
            Assert.Contains(stationId.ToString(), body, StringComparison.OrdinalIgnoreCase);
            Assert.Contains("equipment_fault.create", body, StringComparison.Ordinal);
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("true", Encoding.UTF8, "application/json")
            };
        });
        var service = CreateService(handler);

        Assert.True(await service.HasStationPermissionAsync(
            userId, stationId, "equipment_fault.create"));
    }

    [Theory]
    [InlineData(HttpStatusCode.Forbidden, "true")]
    [InlineData(HttpStatusCode.InternalServerError, "true")]
    [InlineData(HttpStatusCode.OK, "not-json")]
    [InlineData(HttpStatusCode.OK, "null")]
    [InlineData(HttpStatusCode.OK, "false")]
    public async Task Invalid_or_unsuccessful_rpc_response_fails_closed(
        HttpStatusCode statusCode, string body)
    {
        var handler = new StubHandler(_ => new HttpResponseMessage(statusCode)
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json")
        });
        var service = CreateService(handler);

        var allowed = await service.HasStationPermissionAsync(
            Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.create");

        Assert.False(allowed);
    }

    [Fact]
    public async Task Missing_credentials_fail_closed_without_sending_request()
    {
        var handler = new StubHandler(_ => throw new InvalidOperationException("Request must not be sent."));
        var service = CreateService(handler, configured: false);

        var allowed = await service.HasStationPermissionAsync(
            Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.create");

        Assert.False(allowed);
    }

    [Fact]
    public async Task Empty_identity_or_station_fails_closed_without_sending_request()
    {
        var handler = new StubHandler(_ => throw new InvalidOperationException("Request must not be sent."));
        var service = CreateService(handler);

        Assert.False(await service.HasStationPermissionAsync(
            Guid.Empty, Guid.NewGuid(), "equipment_fault.create"));
        Assert.False(await service.HasStationPermissionAsync(
            Guid.NewGuid(), Guid.Empty, "equipment_fault.create"));
        Assert.False(await service.HasStationPermissionAsync(
            Guid.NewGuid(), Guid.NewGuid(), " "));
    }

    private static SupabaseStationAuthorizationService CreateService(
        HttpMessageHandler handler, bool configured = true)
    {
        var settings = new Dictionary<string, string?>
        {
            ["Supabase:Url"] = configured ? "https://example.supabase.co" : null,
            ["Supabase:ServiceRoleKey"] = configured ? "unit-test-secret" : null
        };
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(settings)
            .Build();

        return new SupabaseStationAuthorizationService(
            new StubHttpClientFactory(handler), configuration);
    }

    private sealed class StubHttpClientFactory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
    }

    private sealed class StubHandler(
        Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(respond(request));
    }
}
