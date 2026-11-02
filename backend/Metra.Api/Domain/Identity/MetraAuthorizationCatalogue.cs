namespace Metra.Api.Domain.Identity;

/// <summary>
/// Provider- and persistence-independent definitions for the approved
/// authorization catalogue. Definitions are data; they do not grant access.
/// </summary>
public sealed record MetraRoleDefinition(
    string Code,
    string DisplayName,
    bool IsAssignable = true);

public sealed record MetraPermissionDefinition(
    string Code,
    string DisplayName,
    bool IsEnabled = true);

public sealed record MetraRolePermissionMapping(
    string RoleCode,
    string PermissionCode);

public sealed record MetraAuthorizationCatalogue(
    IReadOnlyCollection<MetraRoleDefinition> Roles,
    IReadOnlyCollection<MetraPermissionDefinition> Permissions,
    IReadOnlyCollection<MetraRolePermissionMapping> RolePermissions);

public sealed record MetraAuthorizationCatalogueValidationResult(
    bool IsValid,
    IReadOnlyList<string> Errors);

/// <summary>
/// Validates catalogue structure only. It deliberately contains no built-in
/// role names, permission names, role mappings, or policy defaults.
/// </summary>
public static class MetraAuthorizationCatalogueValidator
{
    public static MetraAuthorizationCatalogueValidationResult Validate(
        MetraAuthorizationCatalogue? catalogue)
    {
        var errors = new List<string>();
        if (catalogue is null)
            return Invalid("catalogue_required");

        if (catalogue.Roles is null)
            errors.Add("roles_required");
        if (catalogue.Permissions is null)
            errors.Add("permissions_required");
        if (catalogue.RolePermissions is null)
            errors.Add("role_permissions_required");

        if (errors.Count > 0)
            return new(false, errors);

        var roles = catalogue.Roles!;
        var permissions = catalogue.Permissions!;
        var rolePermissions = catalogue.RolePermissions!;

        var roleCodes = new HashSet<string>(StringComparer.Ordinal);
        foreach (var role in roles)
        {
            if (role is null || !IsCanonicalCode(role.Code) ||
                string.IsNullOrWhiteSpace(role.DisplayName))
            {
                errors.Add("role_definition_invalid");
                continue;
            }

            if (!roleCodes.Add(role.Code))
                errors.Add("role_code_duplicate");
        }

        var permissionCodes = new HashSet<string>(StringComparer.Ordinal);
        foreach (var permission in permissions)
        {
            if (permission is null || !IsCanonicalCode(permission.Code) ||
                string.IsNullOrWhiteSpace(permission.DisplayName))
            {
                errors.Add("permission_definition_invalid");
                continue;
            }

            if (!permissionCodes.Add(permission.Code))
                errors.Add("permission_code_duplicate");
        }

        var mappings = new HashSet<(string Role, string Permission)>();
        foreach (var mapping in rolePermissions)
        {
            if (mapping is null ||
                !IsCanonicalCode(mapping.RoleCode) ||
                !IsCanonicalCode(mapping.PermissionCode))
            {
                errors.Add("role_permission_mapping_invalid");
                continue;
            }

            if (!roleCodes.Contains(mapping.RoleCode))
                errors.Add("role_permission_role_unknown");

            if (!permissionCodes.Contains(mapping.PermissionCode))
                errors.Add("role_permission_permission_unknown");

            if (!mappings.Add((mapping.RoleCode, mapping.PermissionCode)))
                errors.Add("role_permission_mapping_duplicate");
        }

        return new(errors.Count == 0, errors);
    }

    /// <summary>
    /// Canonical codes use lowercase ASCII segments separated by one of
    /// '.', '_' or '-'. Display labels remain independently localizable.
    /// </summary>
    private static bool IsCanonicalCode(string? code)
    {
        if (string.IsNullOrEmpty(code) || code.Length > 128)
            return false;

        var segmentHasCharacter = false;
        foreach (var character in code)
        {
            if (character is >= 'a' and <= 'z' or >= '0' and <= '9')
            {
                segmentHasCharacter = true;
                continue;
            }

            if (character is '.' or '_' or '-')
            {
                if (!segmentHasCharacter)
                    return false;

                segmentHasCharacter = false;
                continue;
            }

            return false;
        }

        return segmentHasCharacter;
    }

    private static MetraAuthorizationCatalogueValidationResult Invalid(string error)
        => new(false, [error]);
}
