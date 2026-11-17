using System.Net;
using Microsoft.Extensions.Configuration;
using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class ObservationWriteRpcReadinessProbeTests
{
    [Fact]
    public async Task Submission_probe_accepts_only_the_expected_non_mutating_validation_rejection()
    {
        var service = new SupabaseObservationSubmissionService(
            new StaticClientFactory(new FixedResponseHandler(
                HttpStatusCode.BadRequest,
                """{"code":"22023","message":"user_id_and_station_id_required"}""")),
            Configuration());

        Assert.True(await service.ProbeAsync(CancellationToken.None));
    }

    [Theory]
    [InlineData(HttpStatusCode.NotFound, """{"code":"PGRST202","message":"function not found"}""")]
    [InlineData(HttpStatusCode.Forbidden, """{"code":"42501","message":"permission denied"}""")]
    [InlineData(HttpStatusCode.BadRequest, """{"code":"22023","message":"invalid_observation_type"}""")]
    public async Task Submission_probe_fails_when_rpc_is_missing_or_contract_differs(
        HttpStatusCode status, string body)
    {
        var service = new SupabaseObservationSubmissionService(
            new StaticClientFactory(new FixedResponseHandler(status, body)), Configuration());

        Assert.False(await service.ProbeAsync(CancellationToken.None));
    }

    [Fact]
    public async Task Decision_probe_accepts_only_the_expected_non_mutating_validation_rejection()
    {
        var service = new SupabaseObservationDecisionService(
            new StaticClientFactory(new FixedResponseHandler(
                HttpStatusCode.BadRequest,
                """{"code":"22023","message":"user_station_observation_required"}""")),
            Configuration());

        Assert.True(await service.ProbeAsync(CancellationToken.None));
    }

    [Fact]
    public async Task Decision_probe_fails_when_rpc_is_not_executable()
    {
        var service = new SupabaseObservationDecisionService(
            new StaticClientFactory(new FixedResponseHandler(
                HttpStatusCode.Forbidden,
                """{"code":"42501","message":"permission denied"}""")),
            Configuration());

        Assert.False(await service.ProbeAsync(CancellationToken.None));
    }

    private static IConfiguration Configuration() =>
        new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Supabase:Url"] = "https://metra-test.supabase.co",
            ["Supabase:ServiceRoleKey"] = "test-only-placeholder"
        }).Build();

    private sealed class StaticClientFactory(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) =>
            new(handler, disposeHandler: false) { Timeout = TimeSpan.FromSeconds(8) };
    }

    private sealed class FixedResponseHandler(HttpStatusCode status, string body) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(new HttpResponseMessage(status) { Content = new StringContent(body) });
    }
}
