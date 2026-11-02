using Metra.Api.Security;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace Metra.Api.Tests;

public sealed class SupabaseJwtAuthenticationConfigurationTests
{
    [Fact]
    public void Development_without_provider_settings_keeps_the_fail_closed_scheme()
    {
        var services = new ServiceCollection();
        services.AddLogging();

        services.AddMetraConfiguredAuthentication(
            new ConfigurationBuilder().Build(),
            new TestHostEnvironment { EnvironmentName = Environments.Development });

        using var provider = services.BuildServiceProvider();
        var options = provider.GetRequiredService<IOptions<AuthenticationOptions>>().Value;

        Assert.Equal(MetraAuthenticationDefaults.UnconfiguredScheme, options.DefaultAuthenticateScheme);
        Assert.Equal(MetraAuthenticationDefaults.UnconfiguredScheme, options.DefaultChallengeScheme);
    }

    [Fact]
    public void Non_development_without_provider_settings_fails_startup_configuration()
    {
        var services = new ServiceCollection();

        var exception = Assert.Throws<InvalidOperationException>(() =>
            services.AddMetraConfiguredAuthentication(
                new ConfigurationBuilder().Build(),
                new TestHostEnvironment { EnvironmentName = Environments.Production }));

        Assert.Contains("Authority", exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Configured_provider_uses_exact_issuer_audience_and_asymmetric_algorithms()
    {
        const string issuer = "https://example-project.supabase.co/auth/v1";
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                [SupabaseJwtAuthenticationConfiguration.AuthorityKey] = issuer,
                [SupabaseJwtAuthenticationConfiguration.AudienceKey] = "authenticated"
            })
            .Build();

        var services = new ServiceCollection();
        services.AddLogging();
        services.AddMetraConfiguredAuthentication(
            configuration,
            new TestHostEnvironment { EnvironmentName = Environments.Production });

        using var provider = services.BuildServiceProvider();
        var authentication = provider.GetRequiredService<IOptions<AuthenticationOptions>>().Value;
        var bearer = provider.GetRequiredService<IOptionsMonitor<JwtBearerOptions>>()
            .Get(JwtBearerDefaults.AuthenticationScheme);

        Assert.Equal(JwtBearerDefaults.AuthenticationScheme, authentication.DefaultAuthenticateScheme);
        Assert.Equal(issuer, bearer.Authority);
        Assert.Equal("authenticated", bearer.Audience);
        Assert.True(bearer.RequireHttpsMetadata);
        Assert.False(bearer.SaveToken);
        Assert.False(bearer.MapInboundClaims);
        Assert.Equal(issuer, bearer.TokenValidationParameters.ValidIssuer);
        Assert.Equal("authenticated", bearer.TokenValidationParameters.ValidAudience);
        Assert.Equal(
            new[] { SecurityAlgorithms.RsaSha256, SecurityAlgorithms.EcdsaSha256 },
            bearer.TokenValidationParameters.ValidAlgorithms);
    }

    [Fact]
    public void Non_https_or_root_authority_is_rejected()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                [SupabaseJwtAuthenticationConfiguration.AuthorityKey] = "http://example.com",
                [SupabaseJwtAuthenticationConfiguration.AudienceKey] = "authenticated"
            })
            .Build();

        var services = new ServiceCollection();

        Assert.Throws<InvalidOperationException>(() =>
            services.AddMetraConfiguredAuthentication(
                configuration,
                new TestHostEnvironment { EnvironmentName = Environments.Production }));
    }

    private sealed class TestHostEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Production;
        public string ApplicationName { get; set; } = "Metra.Api.Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
