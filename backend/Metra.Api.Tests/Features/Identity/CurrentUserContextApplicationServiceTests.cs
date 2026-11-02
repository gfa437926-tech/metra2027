using Metra.Api.Features.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class CurrentUserContextApplicationServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 2, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Resolves_account_using_exact_issuer_and_subject_not_email()
    {
        var source = new FakeDataSource(Facts());
        var service = CreateService(source);

        var result = await service.GetAsync(
            "https://identity.example.test/",
            "opaque-provider-subject");

        Assert.NotNull(result);
        Assert.Equal("metra-user-17", result.UserId);
        Assert.Equal("https://identity.example.test/", source.Issuer);
        Assert.Equal("opaque-provider-subject", source.Subject);
    }

    [Fact]
    public async Task Does_not_return_assignments_or_permissions_for_pending_account()
    {
        var source = new FakeDataSource(Facts(
            state: MetraAccountState.PendingSystemApproval));
        var service = CreateService(source);

        var result = await service.GetAsync("issuer", "subject");

        Assert.NotNull(result);
        Assert.Equal("PendingSystemApproval", result.AccountState);
        Assert.Empty(result.Assignments);
        Assert.Empty(result.Permissions);
    }

    [Fact]
    public async Task Filters_expired_and_revoked_assignments_and_permission_grants()
    {
        var facts = Facts() with
        {
            Assignments =
            [
                new("station-current", "Current Station", "observer",
                    Now.AddDays(-1), null, null),
                new("station-expired", "Expired Station", "observer",
                    Now.AddDays(-2), Now, null),
                new("station-revoked", "Revoked Station", "observer",
                    Now.AddDays(-2), null, Now)
            ],
            PermissionGrants =
            [
                new("observations.daily.create", Now.AddDays(-1), null, null),
                new("registrations.system.approve", Now.AddDays(-2), Now, null),
                new("registrations.station.approve", Now.AddDays(-2), null, Now)
            ]
        };
        var service = CreateService(new FakeDataSource(facts));

        var result = await service.GetAsync("issuer", "subject");

        Assert.NotNull(result);
        var assignment = Assert.Single(result.Assignments);
        Assert.Equal("station-current", assignment.StationId);
        Assert.True(assignment.IsActive);
        Assert.Equal(
            ["observations.daily.create"],
            result.Permissions);
    }

    [Fact]
    public async Task Omits_permissions_outside_the_canonical_permission_catalogue()
    {
        var facts = Facts() with
        {
            PermissionGrants =
            [
                new("observations.daily.create", Now.AddDays(-1), null, null),
                new("admin.everything", Now.AddDays(-1), null, null)
            ]
        };
        var service = CreateService(new FakeDataSource(facts));

        var result = await service.GetAsync("issuer", "subject");

        Assert.NotNull(result);
        Assert.Equal(new[] { "observations.daily.create" }, result.Permissions);
    }

    [Fact]
    public async Task Uses_inclusive_start_and_exclusive_end_boundaries()
    {
        var facts = Facts() with
        {
            Assignments =
            [
                new("starts-now", "Starts Now", "observer", Now, null, null),
                new("ends-now", "Ends Now", "observer", Now.AddDays(-1), Now, null)
            ],
            PermissionGrants =
            [
                new("observations.daily.create", Now, null, null),
                new("registrations.system.approve", Now.AddDays(-1), Now, null)
            ]
        };
        var service = CreateService(new FakeDataSource(facts));

        var result = await service.GetAsync("issuer", "subject");

        Assert.NotNull(result);
        Assert.Equal("starts-now", Assert.Single(result.Assignments).StationId);
        Assert.Equal(new[] { "observations.daily.create" }, result.Permissions);
    }

    [Theory]
    [InlineData("", "subject")]
    [InlineData("issuer", "")]
    [InlineData(" ", "subject")]
    [InlineData("issuer", " ")]
    public async Task Rejects_missing_identity_coordinates_before_data_access(
        string issuer,
        string subject)
    {
        var source = new FakeDataSource(Facts());
        var service = CreateService(source);

        var result = await service.GetAsync(issuer, subject);

        Assert.Null(result);
        Assert.Equal(0, source.Calls);
    }

    [Theory]
    [InlineData("issuer\\n", "subject")]
    [InlineData("issuer", "subject\\n")]
    [InlineData("issuer", "")]
    public async Task Rejects_identity_coordinates_containing_control_characters_or_missing_values(
        string issuer,
        string subject)
    {
        var source = new FakeDataSource(Facts());
        var service = CreateService(source);

        var result = await service.GetAsync(issuer, subject);

        Assert.Null(result);
        Assert.Equal(0, source.Calls);
    }

    [Fact]
    public async Task Rejects_oversized_identity_coordinates_before_data_access()
    {
        var source = new FakeDataSource(Facts());
        var service = CreateService(source);

        var result = await service.GetAsync("issuer", new string('s', 257));

        Assert.Null(result);
        Assert.Equal(0, source.Calls);
    }

    [Fact]
    public async Task Returns_null_when_subject_is_not_linked_to_a_metra_account()
    {
        var source = new FakeDataSource(null);
        var service = CreateService(source);

        var result = await service.GetAsync("issuer", "unlinked-subject");

        Assert.Null(result);
    }

    [Fact]
    public async Task Rejects_unknown_account_state_from_authoritative_snapshot()
    {
        var facts = Facts() with { AccountState = (MetraAccountState)999 };
        var service = CreateService(new FakeDataSource(facts));

        var result = await service.GetAsync("issuer", "subject");

        Assert.Null(result);
    }

    [Fact]
    public async Task Rejects_malformed_station_assignment_in_authoritative_snapshot()
    {
        var facts = Facts() with
        {
            Assignments = [new("station/1", "Station", "observer",
                Now.AddDays(-1), null, null)]
        };
        var service = CreateService(new FakeDataSource(facts));

        var result = await service.GetAsync("issuer", "subject");

        Assert.Null(result);
    }

    [Fact]
    public async Task Rejects_non_utc_assignment_timestamp()
    {
        var facts = Facts() with
        {
            Assignments = [new("station-1", "Station", "observer",
                Now.ToOffset(TimeSpan.FromHours(3)), null, null)]
        };
        var service = CreateService(new FakeDataSource(facts));

        var result = await service.GetAsync("issuer", "subject");

        Assert.Null(result);
    }

    [Fact]
    public async Task Rejects_invalid_assignment_validity_window()
    {
        var facts = Facts() with
        {
            Assignments = [new("station-1", "Station", "observer",
                Now, Now.AddTicks(-1), null)]
        };
        var service = CreateService(new FakeDataSource(facts));

        var result = await service.GetAsync("issuer", "subject");

        Assert.Null(result);
    }

    [Fact]
    public async Task Rejects_duplicate_station_role_assignments()
    {
        var assignment = new CurrentUserStationAssignmentFacts(
            "station-1", "Station", "observer", Now.AddDays(-1), null, null);
        var facts = Facts() with { Assignments = [assignment, assignment] };
        var service = CreateService(new FakeDataSource(facts));

        var result = await service.GetAsync("issuer", "subject");

        Assert.Null(result);
    }

    [Fact]
    public async Task Rejects_missing_profile_snapshot()
    {
        var facts = Facts() with { Profile = null! };
        var service = CreateService(new FakeDataSource(facts));

        var result = await service.GetAsync("issuer", "subject");

        Assert.Null(result);
    }

    private static CurrentUserContextApplicationService CreateService(
        FakeDataSource source)
        => new(source, new FrozenTimeProvider(Now));

    private static CurrentUserAccountFacts Facts(
        MetraAccountState state = MetraAccountState.Active)
        => new(
            "metra-user-17",
            state,
            new("First", null, "Last", "verified@example.test", null),
            [new("station-1", "Station One", "observer",
                Now.AddDays(-1), null, null)],
            [new("observations.daily.create", Now.AddDays(-1), null, null)]);

    private sealed class FakeDataSource(CurrentUserAccountFacts? facts)
        : ICurrentUserContextDataSource
    {
        public int Calls { get; private set; }
        public string? Issuer { get; private set; }
        public string? Subject { get; private set; }

        public Task<CurrentUserAccountFacts?> FindByIdentitySubjectAsync(
            string issuer,
            string subject,
            CancellationToken cancellationToken)
        {
            Calls++;
            Issuer = issuer;
            Subject = subject;
            return Task.FromResult(facts);
        }
    }

    private sealed class FrozenTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
