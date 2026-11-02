using Metra.Api.Domain.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class MetraAuthorizationCatalogueValidatorTests
{
    private static MetraAuthorizationCatalogue ValidCatalogue(
        IReadOnlyCollection<MetraRoleDefinition>? roles = null,
        IReadOnlyCollection<MetraPermissionDefinition>? permissions = null,
        IReadOnlyCollection<MetraRolePermissionMapping>? mappings = null)
        => new(
            roles ?? [new("station.operator", "Station operator")],
            permissions ?? [new("observations.read", "Read observations")],
            mappings ?? [new("station.operator", "observations.read")]);

    [Fact]
    public void Valid_catalogue_structure_is_accepted_without_granting_access()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(ValidCatalogue());

        Assert.True(result.IsValid);
        Assert.Empty(result.Errors);
    }

    [Fact]
    public void Null_catalogue_is_rejected()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(null);

        Assert.False(result.IsValid);
        Assert.Contains("catalogue_required", result.Errors);
    }

    [Fact]
    public void Missing_catalogue_collections_are_rejected()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(
            new MetraAuthorizationCatalogue(null!, null!, null!));

        Assert.False(result.IsValid);
        Assert.Contains("roles_required", result.Errors);
        Assert.Contains("permissions_required", result.Errors);
        Assert.Contains("role_permissions_required", result.Errors);
    }

    [Fact]
    public void Duplicate_role_codes_are_rejected_ordinally()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(ValidCatalogue(
            roles: [new("station.operator", "Operator"), new("station.operator", "Operator 2")]));

        Assert.Contains("role_code_duplicate", result.Errors);
    }

    [Fact]
    public void Duplicate_permission_codes_are_rejected_ordinally()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(ValidCatalogue(
            permissions: [new("observations.read", "Read"), new("observations.read", "Read again")]));

        Assert.Contains("permission_code_duplicate", result.Errors);
    }

    [Fact]
    public void Unknown_role_in_mapping_is_rejected()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(ValidCatalogue(
            mappings: [new("unknown.role", "observations.read")]));

        Assert.Contains("role_permission_role_unknown", result.Errors);
    }

    [Fact]
    public void Unknown_permission_in_mapping_is_rejected()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(ValidCatalogue(
            mappings: [new("station.operator", "unknown.permission")]));

        Assert.Contains("role_permission_permission_unknown", result.Errors);
    }

    [Fact]
    public void Duplicate_role_permission_mapping_is_rejected()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(ValidCatalogue(
            mappings:
            [
                new("station.operator", "observations.read"),
                new("station.operator", "observations.read")
            ]));

        Assert.Contains("role_permission_mapping_duplicate", result.Errors);
    }

    [Theory]
    [InlineData("Station.Operator")]
    [InlineData("station..operator")]
    [InlineData(".station")]
    [InlineData("station.")]
    [InlineData("station operator")]
    [InlineData("station/ operator")]
    [InlineData("")]
    public void Noncanonical_role_code_is_rejected(string code)
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(ValidCatalogue(
            roles: [new(code, "Display")],
            mappings: []));

        Assert.Contains("role_definition_invalid", result.Errors);
    }

    [Fact]
    public void Noncanonical_permission_code_is_rejected()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(ValidCatalogue(
            permissions: [new("Observations.Read", "Display")],
            mappings: []));

        Assert.Contains("permission_definition_invalid", result.Errors);
    }

    [Fact]
    public void Blank_display_name_is_rejected()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(ValidCatalogue(
            roles: [new("station.operator", " ")],
            mappings: []));

        Assert.Contains("role_definition_invalid", result.Errors);
    }

    [Fact]
    public void Disabled_permission_and_nonassignable_role_remain_valid_catalogue_data()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(ValidCatalogue(
            roles: [new("legacy.viewer", "Legacy viewer", IsAssignable: false)],
            permissions: [new("observations.read", "Read observations", IsEnabled: false)]));

        Assert.True(result.IsValid);
    }

    [Fact]
    public void Codes_are_case_sensitive_and_not_silently_normalized()
    {
        var result = MetraAuthorizationCatalogueValidator.Validate(ValidCatalogue(
            roles: [new("Station.Operator", "Operator")],
            mappings: []));

        Assert.False(result.IsValid);
    }
}
