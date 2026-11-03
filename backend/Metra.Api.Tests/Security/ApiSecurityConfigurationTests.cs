using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests;

public sealed class ApiSecurityConfigurationTests
{
    [Fact]
    public void Production_requires_at_least_one_allowed_origin()
    {
        var exception = Assert.Throws<InvalidOperationException>(
            () => ApiSecurityConfiguration.ValidateCorsOrigins([], isDevelopment: false));

        Assert.Contains("Cors:AllowedOrigins", exception.Message);
    }

    [Fact]
    public void Development_allows_empty_origins_for_local_non_browser_clients()
    {
        var origins = ApiSecurityConfiguration.ValidateCorsOrigins([], isDevelopment: true);

        Assert.Empty(origins);
    }

    [Fact]
    public void Production_accepts_explicit_https_origin_and_normalizes_trailing_slash()
    {
        var origins = ApiSecurityConfiguration.ValidateCorsOrigins(
            ["https://metra.example.com/"], isDevelopment: false);

        Assert.Equal(["https://metra.example.com"], origins);
    }

    [Theory]
    [InlineData("*")]
    [InlineData("https://metra.example.com/app")]
    [InlineData("https://user:password@metra.example.com")]
    [InlineData("https://metra.example.com?tenant=1")]
    [InlineData("https://metra.example.com#fragment")]
    [InlineData("file:///tmp")]
    [InlineData("not-an-origin")]
    public void Rejects_unsafe_or_invalid_origins(string origin)
    {
        Assert.Throws<InvalidOperationException>(
            () => ApiSecurityConfiguration.ValidateCorsOrigins([origin], isDevelopment: true));
    }

    [Fact]
    public void Production_rejects_plain_http_origin()
    {
        Assert.Throws<InvalidOperationException>(
            () => ApiSecurityConfiguration.ValidateCorsOrigins(
                ["http://metra.example.com"], isDevelopment: false));
    }

    [Fact]
    public void Removes_duplicate_origins_without_case_sensitivity()
    {
        var origins = ApiSecurityConfiguration.ValidateCorsOrigins(
            ["https://metra.example.com", "HTTPS://METRA.EXAMPLE.COM/"],
            isDevelopment: false);

        Assert.Single(origins);
        Assert.Equal("https://metra.example.com", origins[0]);
    }

    [Fact]
    public void Rejects_null_origin_array()
    {
        Assert.Throws<ArgumentNullException>(
            () => ApiSecurityConfiguration.ValidateCorsOrigins(null!, isDevelopment: true));
    }
}
