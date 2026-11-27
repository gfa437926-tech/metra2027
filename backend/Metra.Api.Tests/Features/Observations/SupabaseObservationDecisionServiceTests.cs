using System.Net;
using System.Text;
using System.Text.Json;
using Metra.Api.Features.Observations;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class SupabaseObservationDecisionServiceTests
{
    private static readonly Guid UserId = Guid.Parse("11111111-1111-4111-8111-111111111111");
    private static readonly Guid StationId = Guid.Parse("22222222-2222-4222-8222-222222222222");
    private static readonly Guid ObservationId = Guid.Parse("33333333-3333-4333-8333-333333333333");

    [Theory]
    [InlineData("approve", "approved")]
    [InlineData("return_for_correction", "returned")]
    public async Task Accepts_only_the_expected_persisted_decision_result(string decision, string expectedStatus)
    {
        var body = $$"""{"id":"{{ObservationId}}","status":"{{expectedStatus}}","replayed":false}""";
        var service = CreateService(_ => JsonResponse(HttpStatusCode.OK, body));
        var result = await service.DecideAsync(
            UserId, StationId, ObservationId,
            new ObservationDecisionRequest(decision, decision == "approve" ? null : "سبب واضح"),
            CancellationToken.None);

        Assert.True(result.IsConfigured);
        Assert.True(result.Succeeded);
        Assert.Equal(HttpStatusCode.OK, result.StatusCode);
        Assert.Equal(ObservationId.ToString(), result.Data!.Value.GetProperty("id").GetString());
    }

    [Theory]
    [InlineData("")]
    [InlineData("null")]
    [InlineData("[]")]
    [InlineData("{}")]
    [InlineData("{\"id\":\"33333333-3333-4333-8333-333333333333\",\"status\":\"submitted\",\"replayed\":false}")]
    [InlineData("{\"id\":\"44444444-4444-4444-8444-444444444444\",\"status\":\"approved\",\"replayed\":false}")]
    [InlineData("{\"id\":\"33333333-3333-4333-8333-333333333333\",\"status\":\"approved\"}")]
    [InlineData("not-json")]
    public async Task Invalid_success_body_is_not_reported_as_a_completed_decision(string body)
    {
        var service = CreateService(_ => JsonResponse(HttpStatusCode.OK, body));
        var result = await service.DecideAsync(
            UserId, StationId, ObservationId,
            new ObservationDecisionRequest("approve", null),
            CancellationToken.None);

        Assert.False(result.Succeeded);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, result.StatusCode);
        Assert.Null(result.Data);
    }

    [Fact]
    public async Task Database_failure_is_not_reported_as_a_completed_decision()
    {
        var service = CreateService(_ => new HttpResponseMessage(HttpStatusCode.Forbidden));
        var result = await service.DecideAsync(
            UserId, StationId, ObservationId,
            new ObservationDecisionRequest("approve", null),
            CancellationToken.None);

        Assert.False(result.Succeeded);
        Assert.Equal(HttpStatusCode.Forbidden, result.StatusCode);
        Assert.Null(result.Data);
    }

    private static SupabaseObservationDecisionService CreateService(
        Func<HttpRequestMessage, HttpResponseMessage> responseFactory)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:ServiceRoleKey"] = "server-test-key"
            })
            .Build();

        return new SupabaseObservationDecisionService(
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
