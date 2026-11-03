using Metra.Api.Infrastructure.Database;
using Npgsql;
using Xunit;

namespace Metra.Api.Tests.Infrastructure.Database;

public sealed class MetraDatabaseConfigurationTests
{
    private const string ValidConnectionString =
        "Host=db.example.test;Database=metra;Username=metra_runtime;Password=test-only-secret;SSL Mode=Disable";

    [Fact]
    public void Development_can_start_without_database_configuration()
    {
        Assert.Null(MetraDatabaseConfiguration.BuildConnectionString(null, isDevelopment: true));
    }

    [Fact]
    public void Non_development_requires_database_configuration()
    {
        var exception = Assert.Throws<InvalidOperationException>(
            () => MetraDatabaseConfiguration.BuildConnectionString(null, isDevelopment: false));

        Assert.Contains("ConnectionStrings:MetraDatabase", exception.Message);
    }

    [Fact]
    public void Requires_complete_database_credentials()
    {
        Assert.Throws<InvalidOperationException>(
            () => MetraDatabaseConfiguration.BuildConnectionString(
                "Host=db.example.test;Database=metra;Username=metra_runtime",
                isDevelopment: true));
    }

    [Fact]
    public void Forces_verified_tls_and_safe_pool_defaults()
    {
        var configured = MetraDatabaseConfiguration.BuildConnectionString(
            ValidConnectionString,
            isDevelopment: false);

        var parsed = new NpgsqlConnectionStringBuilder(configured);

        Assert.Equal(SslMode.VerifyFull, parsed.SslMode);
        Assert.True(parsed.Pooling);
        Assert.Equal(0, parsed.MinPoolSize);
        Assert.Equal(50, parsed.MaxPoolSize);
        Assert.Equal(15, parsed.Timeout);
        Assert.Equal(30, parsed.CommandTimeout);
        Assert.False(parsed.IncludeErrorDetail);
        Assert.False(parsed.PersistSecurityInfo);
        Assert.Equal("metra-api", parsed.ApplicationName);
    }

    [Fact]
    public void Does_not_echo_credentials_in_validation_errors()
    {
        var exception = Assert.Throws<InvalidOperationException>(
            () => MetraDatabaseConfiguration.BuildConnectionString(
                "Host=db.example.test;Database=metra",
                isDevelopment: false));

        Assert.DoesNotContain("test-only-secret", exception.Message);
    }
}
