using Metra.Api.Features.Identity;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Metra.Api.Tests.Features.Identity;

public sealed class ConfigurationRegistrationSubmissionCatalogueTests
{
    [Fact]
    public async Task Missing_catalogues_fail_closed()
    {
        var catalogue = new ConfigurationRegistrationSubmissionCatalogue(
            new ConfigurationBuilder().Build());

        Assert.False(await catalogue.IsRoleRequestableAsync("observer", default));
        Assert.False(await catalogue.IsStationSelectableAsync("station-1", default));
    }

    [Fact]
    public async Task Uses_only_deployment_configured_exact_values()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["RegistrationSubmissionCatalogue:RequestableRoleCodes:0"] = "observer",
                ["RegistrationSubmissionCatalogue:RequestableRoleCodes:1"] = "station_manager",
                ["RegistrationSubmissionCatalogue:SelectableStationIds:0"] = "station-001"
            })
            .Build();
        var catalogue = new ConfigurationRegistrationSubmissionCatalogue(configuration);

        Assert.True(await catalogue.IsRoleRequestableAsync("observer", default));
        Assert.True(await catalogue.IsRoleRequestableAsync("station_manager", default));
        Assert.False(await catalogue.IsRoleRequestableAsync("Observer", default));
        Assert.False(await catalogue.IsRoleRequestableAsync("system_admin", default));
        Assert.True(await catalogue.IsStationSelectableAsync("station-001", default));
        Assert.False(await catalogue.IsStationSelectableAsync("station-002", default));
    }

    [Fact]
    public async Task Ignores_blank_configuration_entries_and_trims_configured_values()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["RegistrationSubmissionCatalogue:RequestableRoleCodes:0"] = " ",
                ["RegistrationSubmissionCatalogue:RequestableRoleCodes:1"] = " observer ",
                ["RegistrationSubmissionCatalogue:SelectableStationIds:0"] = ""
            })
            .Build();
        var catalogue = new ConfigurationRegistrationSubmissionCatalogue(configuration);

        Assert.True(await catalogue.IsRoleRequestableAsync("observer", default));
        Assert.False(await catalogue.IsStationSelectableAsync("station-001", default));
    }

    [Fact]
    public async Task Propagates_cancellation()
    {
        var catalogue = new ConfigurationRegistrationSubmissionCatalogue(
            new ConfigurationBuilder().Build());
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        await Assert.ThrowsAsync<OperationCanceledException>(
            () => catalogue.IsRoleRequestableAsync("observer", cancellation.Token));
        await Assert.ThrowsAsync<OperationCanceledException>(
            () => catalogue.IsStationSelectableAsync("station-001", cancellation.Token));
    }
}
