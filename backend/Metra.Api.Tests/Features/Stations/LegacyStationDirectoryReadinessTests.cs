using Metra.Api.Features.Stations;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Metra.Api.Tests.Features.Stations;

public sealed class LegacyStationDirectoryReadinessTests
{
    [Fact]
    public void Legacy_adapter_is_disabled_by_default_even_when_service_role_is_configured()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:ServiceRoleKey"] = "server-only-test-secret"
            })
            .Build();

        var service = new SupabaseStationDirectoryService(
            new EmptyHttpClientFactory(), configuration);

        Assert.False(service.IsConfigured);
    }

    [Fact]
    public void Legacy_adapter_requires_an_explicit_compatibility_flag()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:ServiceRoleKey"] = "server-only-test-secret",
                ["Features:LegacyStationDirectoryEnabled"] = "true"
            })
            .Build();

        var service = new SupabaseStationDirectoryService(
            new EmptyHttpClientFactory(), configuration);

        Assert.True(service.IsConfigured);
    }

    [Fact]
    public void Legacy_station_review_rpc_is_disabled_by_default_even_with_credentials()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:ServiceRoleKey"] = "server-only-test-secret"
            })
            .Build();

        var service = new SupabaseStationCatalogueReviewService(
            new EmptyHttpClientFactory(), configuration);

        Assert.False(service.IsConfigured);
    }

    [Fact]
    public void Legacy_station_review_rpc_requires_its_own_explicit_compatibility_flag()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Supabase:Url"] = "https://example.supabase.co",
                ["Supabase:ServiceRoleKey"] = "server-only-test-secret",
                ["Features:LegacyStationCatalogueReviewEnabled"] = "true"
            })
            .Build();

        var service = new SupabaseStationCatalogueReviewService(
            new EmptyHttpClientFactory(), configuration);

        Assert.True(service.IsConfigured);
    }

    private sealed class EmptyHttpClientFactory : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new();
    }
}
