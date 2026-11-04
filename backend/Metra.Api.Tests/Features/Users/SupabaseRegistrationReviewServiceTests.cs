using System.Net;
using System.Text.Json;
using Metra.Api.Features.Users;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Metra.Api.Tests.Features.Users;

public sealed class SupabaseRegistrationReviewServiceTests
{
    [Theory]
    [InlineData("pending_station_approval", "/rest/v1/rpc/get_station_registration_queue", false)]
    [InlineData("pending_system_approval", "/rest/v1/rpc/get_station_system_registration_queue", true)]
    public async Task Queue_uses_stage_specific_rpc_and_only_sends_actor_for_system_stage(
        string stage, string expectedPath, bool expectsActor)
    {
        var actor = Guid.NewGuid();
        HttpRequestMessage? captured = null;
        string? capturedBody = null;
        var service = CreateService(request =>
        {
            captured = request;
            capturedBody = request.Content!.ReadAsStringAsync().GetAwaiter().GetResult();
            return Ok();
        });

        var result = await service.GetPendingForStationAsync(
            Guid.NewGuid(), stage, 20, actor, CancellationToken.None);

        Assert.NotNull(result);
        Assert.NotNull(captured);
        Assert.Equal(expectedPath, captured.RequestUri!.AbsolutePath);
        using var body = JsonDocument.Parse(capturedBody!);
        Assert.Equal(stage, body.RootElement.GetProperty("p_expected_status").GetString());
        Assert.Equal(expectsActor, body.RootElement.TryGetProperty("p_actor_user_id", out var actorValue));
        if (expectsActor) Assert.Equal(actor, actorValue.GetGuid());
    }

    [Theory]
    [InlineData(false, "/rest/v1/rpc/get_station_registration_audit")]
    [InlineData(true, "/rest/v1/rpc/get_station_system_registration_audit")]
    public async Task Audit_uses_stage_specific_rpc(bool systemStage, string expectedPath)
    {
        var actor = Guid.NewGuid();
        HttpRequestMessage? captured = null;
        string? capturedBody = null;
        var service = CreateService(request =>
        {
            captured = request;
            capturedBody = request.Content!.ReadAsStringAsync().GetAwaiter().GetResult();
            return Ok();
        });

        var result = await service.GetAuditForStationAsync(
            Guid.NewGuid(), 25, actor, systemStage, CancellationToken.None);

        Assert.NotNull(result);
        Assert.NotNull(captured);
        Assert.Equal(expectedPath, captured.RequestUri!.AbsolutePath);
        using var body = JsonDocument.Parse(capturedBody!);
        Assert.Equal(systemStage, body.RootElement.TryGetProperty("p_actor_user_id", out var actorValue));
        if (systemStage) Assert.Equal(actor, actorValue.GetGuid());
    }

    [Fact]
    public async Task System_queue_fails_closed_without_actor_identity()
    {
        var service = CreateService(_ => throw new InvalidOperationException("RPC must not be called"));

        var result = await service.GetPendingForStationAsync(
            Guid.NewGuid(), "pending_system_approval", 20, Guid.Empty, CancellationToken.None);

        Assert.Null(result);
    }

    private static SupabaseRegistrationReviewService CreateService(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:ServiceRoleKey"] = "server-only-test-key"
            })
            .Build();

        return new SupabaseRegistrationReviewService(
            new StubHttpClientFactory(new StubHandler(responseFactory)),
            configuration);
    }

    private static HttpResponseMessage Ok() => new(HttpStatusCode.OK)
    {
        Content = new StringContent("[]", System.Text.Encoding.UTF8, "application/json")
    };

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
