using Metra.Api.Features.EquipmentFaults;
using Metra.Api.Security;

namespace Metra.Api.Tests.EquipmentFaults;

public sealed class EquipmentFaultApplicationServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 7, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Create_requires_valid_submission_and_station_permission()
    {
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(auth, new FakeStationReader());
        var request = new EquipmentFaultSubmission(
            "أجهزة الرصد", "مقياس الحرارة", "توقف الجهاز عن إرسال القراءات.",
            EquipmentFaultSeverity.High, Now, false);

        Assert.True(await service.CanCreateAsync(
            Guid.NewGuid(), Guid.NewGuid(), request, Now));
        Assert.Equal("equipment_fault.create", auth.LastPermission);
    }

    [Fact]
    public async Task Invalid_submission_is_rejected_before_authorization()
    {
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(auth, new FakeStationReader());
        var invalid = new EquipmentFaultSubmission(
            "x", "مقياس الحرارة", "توقف الجهاز عن إرسال القراءات.",
            EquipmentFaultSeverity.High, Now, false);

        Assert.False(await service.CanCreateAsync(
            Guid.NewGuid(), Guid.NewGuid(), invalid, Now));
        Assert.Equal(0, auth.CallCount);
    }

    [Fact]
    public async Task Transition_derives_review_permission_from_domain_policy()
    {
        var stationId = Guid.NewGuid();
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(
            auth, new FakeStationReader { OwnerStationId = stationId });

        var result = await service.AuthorizeTransitionAsync(
            Guid.NewGuid(), stationId, Guid.NewGuid(),
            EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview);

        Assert.Equal(EquipmentFaultAccessResult.Allowed, result);
        Assert.Equal("equipment_fault.review", auth.LastPermission);
        Assert.Equal(1, auth.CallCount);
    }

    [Fact]
    public async Task Invalid_transition_is_rejected_before_repository_or_authorization()
    {
        var reader = new FakeStationReader { OwnerStationId = Guid.NewGuid() };
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(auth, reader);

        var result = await service.AuthorizeTransitionAsync(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            EquipmentFaultStatus.Closed, EquipmentFaultStatus.InProgress);

        Assert.Equal(EquipmentFaultAccessResult.Forbidden, result);
        Assert.Equal(0, reader.CallCount);
        Assert.Equal(0, auth.CallCount);
    }

    [Fact]
    public async Task Transition_checks_persisted_station_before_permission()
    {
        var routeStation = Guid.NewGuid();
        var reader = new FakeStationReader { OwnerStationId = Guid.NewGuid() };
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(auth, reader);

        var result = await service.AuthorizeTransitionAsync(
            Guid.NewGuid(), routeStation, Guid.NewGuid(),
            EquipmentFaultStatus.Submitted, EquipmentFaultStatus.UnderReview);

        Assert.Equal(EquipmentFaultAccessResult.NotFoundOrWrongStation, result);
        Assert.Equal(0, auth.CallCount);
    }

    [Fact]
    public async Task Transition_denies_when_required_permission_is_missing()
    {
        var stationId = Guid.NewGuid();
        var auth = new FakeAuthorization { Allowed = false };
        var service = new EquipmentFaultApplicationService(
            auth, new FakeStationReader { OwnerStationId = stationId });

        var result = await service.AuthorizeTransitionAsync(
            Guid.NewGuid(), stationId, Guid.NewGuid(),
            EquipmentFaultStatus.UnderReview, EquipmentFaultStatus.Assigned);

        Assert.Equal(EquipmentFaultAccessResult.Forbidden, result);
        Assert.Equal("equipment_fault.assign", auth.LastPermission);
    }

    [Fact]
    public async Task Record_access_checks_persisted_station_before_permission()
    {
        var routeStation = Guid.NewGuid();
        var reader = new FakeStationReader { OwnerStationId = Guid.NewGuid() };
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(auth, reader);

        var result = await service.AuthorizeRecordAsync(
            Guid.NewGuid(), routeStation, Guid.NewGuid(), "equipment_fault.read");

        Assert.Equal(EquipmentFaultAccessResult.NotFoundOrWrongStation, result);
        Assert.Equal(0, auth.CallCount);
    }

    [Fact]
    public async Task Matching_station_still_requires_permission()
    {
        var stationId = Guid.NewGuid();
        var auth = new FakeAuthorization { Allowed = false };
        var service = new EquipmentFaultApplicationService(
            auth, new FakeStationReader { OwnerStationId = stationId });

        var result = await service.AuthorizeRecordAsync(
            Guid.NewGuid(), stationId, Guid.NewGuid(), "equipment_fault.read");

        Assert.Equal(EquipmentFaultAccessResult.Forbidden, result);
        Assert.Equal("equipment_fault.read", auth.LastPermission);
    }

    [Fact]
    public async Task Matching_station_and_permission_are_required_for_access()
    {
        var stationId = Guid.NewGuid();
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(
            auth, new FakeStationReader { OwnerStationId = stationId });

        var result = await service.AuthorizeRecordAsync(
            Guid.NewGuid(), stationId, Guid.NewGuid(), "equipment_fault.read");

        Assert.Equal(EquipmentFaultAccessResult.Allowed, result);
    }

    [Fact]
    public async Task Repository_timeout_fails_closed_without_authorization()
    {
        var reader = new FakeStationReader { ThrowTimeout = true };
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(auth, reader);

        var result = await service.AuthorizeRecordAsync(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.read");

        Assert.Equal(EquipmentFaultAccessResult.Forbidden, result);
        Assert.Equal(0, auth.CallCount);
    }

    [Fact]
    public async Task Repository_http_failure_fails_closed_without_authorization()
    {
        var reader = new FakeStationReader { ThrowHttpFailure = true };
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(auth, reader);

        var result = await service.AuthorizeRecordAsync(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.read");

        Assert.Equal(EquipmentFaultAccessResult.Forbidden, result);
        Assert.Equal(0, auth.CallCount);
    }

    [Fact]
    public async Task Caller_cancellation_is_not_converted_to_access_denial()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var reader = new FakeStationReader { ThrowCallerCancellation = true };
        var service = new EquipmentFaultApplicationService(
            new FakeAuthorization { Allowed = true }, reader);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            service.AuthorizeRecordAsync(
                Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
                "equipment_fault.read", cancellation.Token));
    }

    [Fact]
    public async Task Empty_identity_or_fault_id_is_rejected_before_repository_access()
    {
        var reader = new FakeStationReader { OwnerStationId = Guid.NewGuid() };
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(auth, reader);

        var result = await service.AuthorizeRecordAsync(
            Guid.Empty, Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.read");

        Assert.Equal(EquipmentFaultAccessResult.NotFoundOrWrongStation, result);
        Assert.Equal(0, reader.CallCount);
        Assert.Equal(0, auth.CallCount);
    }

    [Fact]
    public async Task Missing_record_is_not_found_or_wrong_station()
    {
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(auth, new FakeStationReader());

        var result = await service.AuthorizeRecordAsync(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "equipment_fault.read");

        Assert.Equal(EquipmentFaultAccessResult.NotFoundOrWrongStation, result);
        Assert.Equal(0, auth.CallCount);
    }

    private sealed class FakeStationReader : IEquipmentFaultStationReader
    {
        public Guid? OwnerStationId { get; init; }
        public bool ThrowTimeout { get; init; }
        public bool ThrowHttpFailure { get; init; }
        public bool ThrowCallerCancellation { get; init; }
        public int CallCount { get; private set; }

        public Task<Guid?> GetOwningStationIdAsync(Guid faultId, CancellationToken cancellationToken)
        {
            CallCount++;
            if (ThrowCallerCancellation)
                throw new OperationCanceledException(cancellationToken);
            if (ThrowHttpFailure)
                throw new HttpRequestException("simulated repository failure");
            if (ThrowTimeout)
                throw new TaskCanceledException("simulated repository timeout");
            return Task.FromResult(OwnerStationId);
        }
    }

    private sealed class FakeAuthorization : IStationAuthorizationService
    {
        public bool IsConfigured { get; set; } = true;
        public bool Allowed { get; set; }
        public int CallCount { get; private set; }
        public string? LastPermission { get; private set; }

        public Task<bool> HasStationPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            LastPermission = permissionCode;
            return Task.FromResult(Allowed);
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(false);
    }
}
