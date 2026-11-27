using System.Net;
using System.Text;
using System.Text.Json;
using Metra.Api.Features.Observations;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class SupabaseObservationSubmissionServiceTests
{
    private static readonly Guid UserId = Guid.Parse("11111111-1111-4111-8111-111111111111");
    private static readonly Guid StationId = Guid.Parse("22222222-2222-4222-8222-222222222222");

    [Fact]
    public async Task Sends_server_authenticated_atomic_rpc_with_expected_identity_and_payload()
    {
        string? capturedBody = null;
        string? capturedPath = null;
        string? capturedMethod = null;
        string? capturedApiKey = null;
        string? capturedAuthScheme = null;
        string? capturedAuthParameter = null;
        var service = CreateService(request =>
        {
            capturedPath = request.RequestUri!.AbsolutePath;
            capturedMethod = request.Method.Method;
            capturedApiKey = request.Headers.GetValues("apikey").Single();
            capturedAuthScheme = request.Headers.Authorization!.Scheme;
            capturedAuthParameter = request.Headers.Authorization.Parameter;
            // HttpClient disposes the request and its content after SendAsync.
            // Read the body while the handler still owns the live request.
            capturedBody = request.Content!.ReadAsStringAsync().GetAwaiter().GetResult();
            return JsonResponse(HttpStatusCode.OK, "{\"id\":\"obs-1\",\"status\":\"submitted\"}");
        });

        using var payloadDocument = JsonDocument.Parse("{\"temperature\":21}");
        var request = new ObservationSubmissionRequest(
            "stable-key", "hourly", DateTimeOffset.Parse("2026-11-27T12:00:00Z"),
            payloadDocument.RootElement.Clone(), true);

        var result = await service.SubmitAsync(UserId, StationId, request, CancellationToken.None);

        Assert.True(result.IsConfigured);
        Assert.True(result.Succeeded);
        Assert.Equal(HttpStatusCode.OK, result.StatusCode);
        Assert.Equal("/rest/v1/rpc/metra_submit_observation", capturedPath);
        Assert.Equal("POST", capturedMethod);
        Assert.Equal("server-test-key", capturedApiKey);
        Assert.Equal("Bearer", capturedAuthScheme);
        Assert.Equal("server-test-key", capturedAuthParameter);

        using var body = JsonDocument.Parse(capturedBody!);
        var root = body.RootElement;
        Assert.Equal(UserId, root.GetProperty("p_user_id").GetGuid());
        Assert.Equal(StationId, root.GetProperty("p_station_id").GetGuid());
        Assert.Equal("stable-key", root.GetProperty("p_idempotency_key").GetString());
        Assert.Equal("hourly", root.GetProperty("p_observation_type").GetString());
        Assert.True(root.GetProperty("p_submit").GetBoolean());
        Assert.Equal(21, root.GetProperty("p_payload").GetProperty("temperature").GetInt32());
        Assert.NotNull(result.Data);
        Assert.Equal("33333333-3333-4333-8333-333333333333", result.Data!.Value.GetProperty("id").GetString());
    }

    [Theory]
    [InlineData(HttpStatusCode.Forbidden)]
    [InlineData(HttpStatusCode.Conflict)]
    [InlineData(HttpStatusCode.BadRequest)]
    [InlineData(HttpStatusCode.InternalServerError)]
    public async Task Returns_database_failure_status_without_claiming_success(HttpStatusCode status)
    {
        var service = CreateService(_ => new HttpResponseMessage(status));
        using var payloadDocument = JsonDocument.Parse("{}");
        var request = new ObservationSubmissionRequest(
            "key", "daily", DateTimeOffset.UtcNow, payloadDocument.RootElement.Clone());

        var result = await service.SubmitAsync(UserId, StationId, request, CancellationToken.None);

        Assert.True(result.IsConfigured);
        Assert.False(result.Succeeded);
        Assert.Equal(status, result.StatusCode);
        Assert.Null(result.Data);
    }

    [Theory]
    [InlineData("")]
    [InlineData("null")]
    [InlineData("[]")]
    [InlineData("\"ok\"")]
    [InlineData("{}")]
    [InlineData("{\"id\":\"33333333-3333-4333-8333-333333333333\",\"status\":\"submitted\"}")]
    [InlineData("not-json")]
    public async Task Invalid_success_body_is_not_reported_as_persisted(string body)
    {
        var service = CreateService(_ =>
            new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json")
            });
        using var payloadDocument = JsonDocument.Parse("{}");
        var request = new ObservationSubmissionRequest(
            "key", "daily", DateTimeOffset.UtcNow, payloadDocument.RootElement.Clone());

        var result = await service.SubmitAsync(UserId, StationId, request, CancellationToken.None);

        Assert.False(result.Succeeded);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, result.StatusCode);
        Assert.Null(result.Data);
    }

    [Fact]
    public async Task Non_https_supabase_url_disables_service()
    {
        var service = CreateService(
            _ => throw new InvalidOperationException("Unconfigured service must not send requests."),
            url: "http://example.supabase.co");

        Assert.False(service.IsConfigured);
        using var payloadDocument = JsonDocument.Parse("{}");
        var request = new ObservationSubmissionRequest(
            "key", "daily", DateTimeOffset.UtcNow, payloadDocument.RootElement.Clone());

        var result = await service.SubmitAsync(UserId, StationId, request, CancellationToken.None);

        Assert.False(result.IsConfigured);
        Assert.False(result.Succeeded);
    }

    private static SupabaseObservationSubmissionService CreateService(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory,
        string url = "https://example.supabase.co")
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = url,
                ["Supabase:ServiceRoleKey"] = "server-test-key"
            })
            .Build();

        return new SupabaseObservationSubmissionService(
            new StubHttpClientFactory(new StubHandler(responseFactory)), configuration);
    }

    private static HttpResponseMessage JsonResponse(HttpStatusCode status, string json) =>
        new(status) { Content = new StringContent(json, Encoding.UTF8, "application/json") };

    private sealed class StubHttpClientFactory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
    }

    private sealed class StubHandler(Func<HttpRequestMessage, HttpResponseMessage> responseFactory)
        : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(responseFactory(request));
    }
}
