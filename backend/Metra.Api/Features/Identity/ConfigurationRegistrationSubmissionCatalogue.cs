using Microsoft.Extensions.Configuration;

namespace Metra.Api.Features.Identity;

/// <summary>
/// Fail-closed catalogue adapter backed only by deployment-controlled
/// configuration. It deliberately contains no guessed METRA role or station
/// identifiers. Empty or missing allowlists make every request unavailable.
/// Replace this source with the authoritative read-only catalogue adapter
/// before production onboarding is enabled.
/// </summary>
public sealed class ConfigurationRegistrationSubmissionCatalogue : IRegistrationSubmissionCatalogue
{
    private const string RolesSection = "RegistrationSubmissionCatalogue:RequestableRoleCodes";
    private const string StationsSection = "RegistrationSubmissionCatalogue:SelectableStationIds";

    private readonly HashSet<string> _requestableRoleCodes;
    private readonly HashSet<string> _selectableStationIds;

    public ConfigurationRegistrationSubmissionCatalogue(IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        _requestableRoleCodes = ReadAllowlist(configuration, RolesSection);
        _selectableStationIds = ReadAllowlist(configuration, StationsSection);
    }

    public Task<bool> IsRoleRequestableAsync(
        string roleCode,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(
            !string.IsNullOrWhiteSpace(roleCode) &&
            _requestableRoleCodes.Contains(roleCode));
    }

    public Task<bool> IsStationSelectableAsync(
        string stationId,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(
            !string.IsNullOrWhiteSpace(stationId) &&
            _selectableStationIds.Contains(stationId));
    }

    private static HashSet<string> ReadAllowlist(
        IConfiguration configuration,
        string sectionPath)
    {
        var values = configuration.GetSection(sectionPath).Get<string[]>() ?? [];

        return values
            .Where(static value => !string.IsNullOrWhiteSpace(value))
            .Select(static value => value.Trim())
            .ToHashSet(StringComparer.Ordinal);
    }
}
