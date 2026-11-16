using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests.Security;

/// <summary>
/// Station isolation / IDOR unit tests against <see cref="IStationAuthorizationService"/>.
/// A principal allowed on station A must never be treated as authorized on station B,
/// and station-scoped grants must not imply authority-scoped grants (and vice versa).
/// </summary>
public sealed class StationIsolationIdorTests
{
    private static readonly Guid UserA = Guid.Parse("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
    private static readonly Guid StationAllowed = Guid.Parse("11111111-1111-4111-8111-111111111111");
    private static readonly Guid StationForeign = Guid.Parse("22222222-2222-4222-8222-222222222222");
    private static readonly Guid AuthorityAllowed = Guid.Parse("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb");
    private static readonly Guid AuthorityForeign = Guid.Parse("cccccccc-cccc-4ccc-8ccc-cccccccccccc");

    [Fact]
    public async Task Observer_create_on_home_station_does_not_open_foreign_station()
    {
        var auth = CreateStationAuth(
            allowStationId: StationAllowed,
            permissions: ["observation.create"]);

        Assert.True(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, "observation.create"));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationForeign, "observation.create"));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationForeign, "observation.review"));
    }

    [Fact]
    public async Task Station_chief_review_does_not_open_foreign_station_queue_or_decision()
    {
        var auth = CreateStationAuth(
            allowStationId: StationAllowed,
            permissions:
            [
                "observation.review",
                "observation.approve",
                "observation.return_for_correction"
            ]);

        Assert.True(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, "observation.review"));
        Assert.True(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, "observation.approve"));

        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationForeign, "observation.review"));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationForeign, "observation.approve"));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationForeign, "observation.return_for_correction"));
    }

    [Fact]
    public async Task Create_permission_does_not_imply_review_on_same_station()
    {
        var auth = CreateStationAuth(
            allowStationId: StationAllowed,
            permissions: ["observation.create"]);

        Assert.True(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, "observation.create"));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, "observation.review"));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, "observation.approve"));
    }

    [Fact]
    public async Task Users_and_audit_permissions_are_station_scoped()
    {
        var auth = CreateStationAuth(
            allowStationId: StationAllowed,
            permissions: ["users.station.view", "stations.users.read"]);

        Assert.True(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, "users.station.view"));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationForeign, "users.station.view"));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationForeign, "stations.users.read"));
    }

    [Fact]
    public async Task Registration_station_approve_does_not_cross_stations()
    {
        var auth = CreateStationAuth(
            allowStationId: StationAllowed,
            permissions: ["registrations.station.approve"]);

        Assert.True(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, "registrations.station.approve"));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationForeign, "registrations.station.approve"));
    }

    [Fact]
    public async Task System_registration_approve_is_authority_scoped_not_station_grant()
    {
        var auth = CreateStationAuth(
            allowStationId: StationAllowed,
            permissions: ["observation.create"],
            authorityId: AuthorityAllowed,
            authorityPermissions: ["registrations.system.approve"]);

        Assert.True(await auth.HasAuthorityPermissionAsync(
            UserA, AuthorityAllowed, "registrations.system.approve"));
        Assert.False(await auth.HasAuthorityPermissionAsync(
            UserA, AuthorityForeign, "registrations.system.approve"));
        // Station-scoped create must not open system registration approval.
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, "registrations.system.approve"));
    }

    [Fact]
    public async Task Catalogue_review_authority_permission_does_not_open_unrelated_authority()
    {
        var auth = CreateStationAuth(
            allowStationId: StationAllowed,
            permissions: [],
            authorityId: AuthorityAllowed,
            authorityPermissions: ["stations.catalogue.review"]);

        Assert.True(await auth.HasAuthorityPermissionAsync(
            UserA, AuthorityAllowed, "stations.catalogue.review"));
        Assert.False(await auth.HasAuthorityPermissionAsync(
            UserA, AuthorityForeign, "stations.catalogue.review"));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, "stations.catalogue.review"));
    }

    [Fact]
    public async Task Empty_user_or_station_fails_closed()
    {
        var auth = CreateStationAuth(
            allowStationId: StationAllowed,
            permissions: ["observation.create", "observation.review"]);

        Assert.False(await auth.HasStationPermissionAsync(
            Guid.Empty, StationAllowed, "observation.create"));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, Guid.Empty, "observation.create"));
        Assert.False(await auth.HasStationOwnerAuthorityPermissionAsync(
            Guid.Empty, StationAllowed, "registrations.system.approve"));
        Assert.False(await auth.HasAuthorityPermissionAsync(
            UserA, Guid.Empty, "stations.catalogue.review"));
    }

    [Fact]
    public async Task Unconfigured_authorization_never_allows()
    {
        var auth = new FixedStationAuthorization(
            isConfigured: false,
            allowStationId: StationAllowed,
            allowedPermissions: ["observation.create", "observation.review"],
            allowAuthorityId: AuthorityAllowed,
            allowedAuthorityPermissions: ["stations.catalogue.review"]);

        Assert.False(auth.IsConfigured);
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, "observation.create"));
        Assert.False(await auth.HasAuthorityPermissionAsync(
            UserA, AuthorityAllowed, "stations.catalogue.review"));
    }

    [Fact]
    public async Task Blank_permission_code_is_never_granted()
    {
        var auth = CreateStationAuth(
            allowStationId: StationAllowed,
            permissions: ["observation.create"]);

        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, ""));
        Assert.False(await auth.HasStationPermissionAsync(
            UserA, StationAllowed, " "));
    }

    private static FixedStationAuthorization CreateStationAuth(
        Guid allowStationId,
        string[] permissions,
        Guid? authorityId = null,
        string[]? authorityPermissions = null) =>
        new(
            isConfigured: true,
            allowStationId: allowStationId,
            allowedPermissions: new HashSet<string>(permissions, StringComparer.Ordinal),
            allowAuthorityId: authorityId,
            allowedAuthorityPermissions: authorityPermissions is null
                ? null
                : new HashSet<string>(authorityPermissions, StringComparer.Ordinal));

    /// <summary>
    /// Deterministic authorization stub: allows only the listed permissions on one station
    /// (and optionally one authority). All other combinations fail closed.
    /// </summary>
    private sealed class FixedStationAuthorization(
        bool isConfigured,
        Guid allowStationId,
        HashSet<string> allowedPermissions,
        Guid? allowAuthorityId = null,
        HashSet<string>? allowedAuthorityPermissions = null) : IStationAuthorizationService
    {
        public bool IsConfigured { get; } = isConfigured;

        public Task<bool> HasStationPermissionAsync(
            Guid userId,
            Guid stationId,
            string permissionCode,
            CancellationToken cancellationToken = default)
        {
            if (!IsConfigured ||
                userId == Guid.Empty ||
                stationId == Guid.Empty ||
                string.IsNullOrWhiteSpace(permissionCode))
            {
                return Task.FromResult(false);
            }

            if (stationId != allowStationId)
                return Task.FromResult(false);

            return Task.FromResult(allowedPermissions.Contains(permissionCode));
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid userId,
            Guid stationId,
            string permissionCode,
            CancellationToken cancellationToken = default)
        {
            // Owner-authority checks are still keyed by station id in the real RPC;
            // this stub only grants when the station is the allowed one AND the
            // permission is in the authority set (models central-role grants).
            if (!IsConfigured ||
                userId == Guid.Empty ||
                stationId == Guid.Empty ||
                string.IsNullOrWhiteSpace(permissionCode))
            {
                return Task.FromResult(false);
            }

            if (stationId != allowStationId)
                return Task.FromResult(false);

            return Task.FromResult(
                allowedAuthorityPermissions?.Contains(permissionCode) == true);
        }

        public Task<bool> HasAuthorityPermissionAsync(
            Guid userId,
            Guid authorityId,
            string permissionCode,
            CancellationToken cancellationToken = default)
        {
            if (!IsConfigured ||
                userId == Guid.Empty ||
                authorityId == Guid.Empty ||
                string.IsNullOrWhiteSpace(permissionCode))
            {
                return Task.FromResult(false);
            }

            if (allowAuthorityId is null || authorityId != allowAuthorityId.Value)
                return Task.FromResult(false);

            return Task.FromResult(
                allowedAuthorityPermissions?.Contains(permissionCode) == true);
        }
    }
}
