using Metra.Api.Features.EquipmentFaults;
using Metra.Api.Security;
using Xunit;

namespace Metra.Api.Tests.EquipmentFaults;

public sealed class EquipmentFaultAuthorizationTests
{
    [Fact]
    public async Task Authorization_uses_the_exact_route_station_and_authenticated_user()
    {
        var userId = Guid.Parse("11111111-1111-1111-1111-111111111111");
        var stationId = Guid.Parse("22222222-2222-2222-2222-222222222222");
        var authorization = new AuthorizationStub { Result = true };

        var allowed = await EquipmentFaultAuthorization.HasStationPermissionAsync(
            authorization, userId, stationId, "equipment_fault.create");

        Assert.True(allowed);
        Assert.Equal(userId, authorization.LastUserId);
        Assert.Equal(stationId, authorization.LastStationId);
        Assert.Equal("equipment_fault.create", authorization.LastPermission);
    }

    [Fact]
    public async Task Authorization_fails_closed_when_service_is_not_configured()
    {
        var authorization = new AuthorizationStub { IsConfigured = false, Result = true };

        var allowed = await EquipmentFaultAuthorization.HasStationPermissionAsync(
            authorization, Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.create");

        Assert.False(allowed);
        Assert.Equal(0, authorization.CallCount);
    }

    [Fact]
    public async Task Authorization_fails_closed_when_dependency_throws_http_error()
    {
        var authorization = new AuthorizationStub
        {
            Exception = new HttpRequestException("authorization dependency unavailable")
        };

        var allowed = await EquipmentFaultAuthorization.HasStationPermissionAsync(
            authorization, Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.create");

        Assert.False(allowed);
        Assert.Equal(1, authorization.CallCount);
    }

    [Fact]
    public async Task Authorization_fails_closed_on_unexpected_dependency_error()
    {
        var authorization = new AuthorizationStub
        {
            Exception = new InvalidOperationException("unexpected provider failure")
        };

        var allowed = await EquipmentFaultAuthorization.HasStationPermissionAsync(
            authorization, Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.create");

        Assert.False(allowed);
        Assert.Equal(1, authorization.CallCount);
    }

    [Fact]
    public async Task Authorization_fails_closed_on_upstream_timeout()
    {
        var authorization = new AuthorizationStub
        {
            Exception = new TaskCanceledException("upstream timed out")
        };

        var allowed = await EquipmentFaultAuthorization.HasStationPermissionAsync(
            authorization, Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.create");

        Assert.False(allowed);
        Assert.Equal(1, authorization.CallCount);
    }

    [Fact]
    public async Task Authorization_preserves_explicit_caller_cancellation()
    {
        using var source = new CancellationTokenSource();
        source.Cancel();
        var authorization = new AuthorizationStub
        {
            Exception = new TaskCanceledException("caller cancelled")
        };

        await Assert.ThrowsAsync<TaskCanceledException>(() =>
            EquipmentFaultAuthorization.HasStationPermissionAsync(
                authorization, Guid.NewGuid(), Guid.NewGuid(),
                "equipment_fault.create", source.Token));
    }

    [Theory]
    [InlineData(true, false, "equipment_fault.create")]
    [InlineData(false, true, "equipment_fault.create")]
    [InlineData(false, false, " ")]
    public async Task Empty_identifiers_or_permission_never_call_authorization(
        bool emptyUser, bool emptyStation, string permission)
    {
        var authorization = new AuthorizationStub();
        var userId = emptyUser ? Guid.Empty : Guid.NewGuid();
        var stationId = emptyStation ? Guid.Empty : Guid.NewGuid();

        var allowed = await EquipmentFaultAuthorization.HasStationPermissionAsync(
            authorization, userId, stationId, permission);

        Assert.False(allowed);
        Assert.Equal(0, authorization.CallCount);
    }

    [Fact]
    public async Task Transition_permission_is_derived_from_domain_state_change()
    {
        var authorization = new AuthorizationStub { Result = true };
        var userId = Guid.NewGuid();
        var stationId = Guid.NewGuid();

        var allowed = await EquipmentFaultAuthorization.CanTransitionAsync(
            authorization, userId, stationId,
            EquipmentFaultStatus.UnderReview, EquipmentFaultStatus.Assigned);

        Assert.True(allowed);
        Assert.Equal("equipment_fault.assign", authorization.LastPermission);
        Assert.Equal(stationId, authorization.LastStationId);
    }

    [Fact]
    public async Task Invalid_transition_is_denied_without_authorization_call()
    {
        var authorization = new AuthorizationStub { Result = true };

        var allowed = await EquipmentFaultAuthorization.CanTransitionAsync(
            authorization, Guid.NewGuid(), Guid.NewGuid(),
            EquipmentFaultStatus.Submitted, EquipmentFaultStatus.Closed);

        Assert.False(allowed);
        Assert.Equal(0, authorization.CallCount);
    }

    private sealed class AuthorizationStub : IStationAuthorizationService
    {
        public bool IsConfigured { get; init; } = true;
        public bool Result { get; init; }
        public Exception? Exception { get; init; }
        public int CallCount { get; private set; }
        public Guid LastUserId { get; private set; }
        public Guid LastStationId { get; private set; }
        public string? LastPermission { get; private set; }

        public Task<bool> HasStationPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            LastUserId = userId;
            LastStationId = stationId;
            LastPermission = permissionCode;

            return Exception is not null
                ? Task.FromException<bool>(Exception)
                : Task.FromResult(Result);
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(false);
    }
}
