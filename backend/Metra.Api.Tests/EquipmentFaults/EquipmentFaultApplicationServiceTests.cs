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
    public async Task Create_rejects_empty_user_or_station_before_authorization()
    {
        var auth = new FakeAuthorization { Allowed = true };
        var service = new EquipmentFaultApplicationService(auth, new FakeStationReader());
        var valid = new EquipmentFaultSubmission(
            "أجهزة الرصد", "مقياس الحرارة", "توقف الجهاز عن إرسال القراءات.",
            EquipmentFaultSeverity.High, Now, false);

        Assert.False(await service.CanCreateAsync(
            Guid.Empty, Guid.NewGuid(), valid, Now));
        Assert.False(await service.CanCreateAsync(
            Guid.NewGuid(), Guid.Empty, valid, Now));
        Assert.Equal(0, auth.CallCount);
    }

    [Fact]
    public async Task Create_denies_when_authorization_is_not_configured()
    {
        var auth = new FakeAuthorization { IsConfigured = false, Allowed = true };
        var service = new EquipmentFaultApplicationService(auth, new FakeStationReader());
        var valid = new EquipmentFaultSubmission(
            "أجهزة الرصد", "مقياس الحرارة", "توقف الجهاز عن إرسال القراءات.",
            EquipmentFaultSeverity.High, Now, false);

        Assert.False(await service.CanCreateAsync(
            Guid.NewGuid(), Guid.NewGuid(), valid, Now));
        Assert.Equal(0, auth.CallCount);
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
    public async Task Unexpected_repository_failure_fails_closed_without_authorization()
    {
        var reader = new FakeStationReader { ThrowUnexpectedFailure = true };
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
        public bool ThrowUnexpectedFailure { get; init; }
        public int CallCount { get; private set; }

        public Task<Guid?> GetOwningStationIdAsync(Guid faultId, CancellationToken cancellationToken)
        {
            CallCount++;
            if (ThrowCallerCancellation)
                throw new OperationCanceledException(cancellationToken);
            if (ThrowUnexpectedFailure)
                throw new InvalidOperationException("simulated unexpected repository failure");
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

public sealed class EquipmentFaultReadServiceTests
{
    [Fact]
    public async Task List_authorizes_then_passes_station_and_bounded_window_to_store()
    {
        var stationId = Guid.NewGuid();
        var auth = new ReadFakeAuthorization { Allowed = true };
        var store = new ReadFakeStore();
        var service = new EquipmentFaultReadService(auth, store);
        var query = new EquipmentFaultListQuery(
            3, 20, EquipmentFaultStatus.Submitted, null, null, null);

        var result = await service.GetPageAsync(
            Guid.NewGuid(), stationId, query);

        Assert.Equal(EquipmentFaultReadResultCode.Success, result.Code);
        Assert.Equal(stationId, store.ListStationId);
        Assert.Equal(3, store.Window?.Page);
        Assert.Equal(20, store.Window?.PageSize);
        Assert.Equal(40, store.Window?.Offset);
        Assert.Equal(EquipmentFaultListSort.OccurredAtDescending, store.Sort);
        Assert.Equal("equipment_fault.read", auth.Permission);
    }

    [Fact]
    public async Task List_denial_never_calls_store()
    {
        var store = new ReadFakeStore();
        var service = new EquipmentFaultReadService(
            new ReadFakeAuthorization { Allowed = false }, store);

        var result = await service.GetPageAsync(
            Guid.NewGuid(), Guid.NewGuid(),
            new EquipmentFaultListQuery(1, 25, null, null, null, null));

        Assert.Equal(EquipmentFaultReadResultCode.Forbidden, result.Code);
        Assert.Equal(0, store.ListCalls);
    }

    [Fact]
    public async Task Invalid_list_query_is_rejected_before_authorization_or_store()
    {
        var auth = new ReadFakeAuthorization { Allowed = true };
        var store = new ReadFakeStore();
        var service = new EquipmentFaultReadService(auth, store);

        var result = await service.GetPageAsync(
            Guid.NewGuid(), Guid.NewGuid(),
            new EquipmentFaultListQuery(0, 25, null, null, null, null));

        Assert.Equal(EquipmentFaultReadResultCode.InvalidRequest, result.Code);
        Assert.Equal(0, auth.CallCount);
        Assert.Equal(0, store.ListCalls);
    }

    [Fact]
    public async Task Undefined_sort_is_rejected_before_authorization_or_store()
    {
        var auth = new ReadFakeAuthorization { Allowed = true };
        var store = new ReadFakeStore();
        var service = new EquipmentFaultReadService(auth, store);
        var query = new EquipmentFaultListQuery(
            1, 25, null, null, null, null, (EquipmentFaultListSort)999);

        var result = await service.GetPageAsync(
            Guid.NewGuid(), Guid.NewGuid(), query);

        Assert.Equal(EquipmentFaultReadResultCode.InvalidRequest, result.Code);
        Assert.Equal(0, auth.CallCount);
        Assert.Equal(0, store.ListCalls);
    }

    [Fact]
    public async Task Detail_is_scoped_by_both_ids_and_mismatch_is_not_disclosed()
    {
        var stationId = Guid.NewGuid();
        var faultId = Guid.NewGuid();
        var store = new ReadFakeStore
        {
            Detail = new EquipmentFaultDetail(
                faultId, Guid.NewGuid(), Guid.NewGuid(),
                "أجهزة", "مقياس", "وصف العطل التفصيلي",
                EquipmentFaultSeverity.High, EquipmentFaultStatus.Submitted,
                DateTimeOffset.UtcNow)
        };
        var service = new EquipmentFaultReadService(
            new ReadFakeAuthorization { Allowed = true }, store);

        var result = await service.GetDetailAsync(
            Guid.NewGuid(), stationId, faultId);

        Assert.Equal(EquipmentFaultReadResultCode.NotFoundOrWrongStation, result.Code);
        Assert.Equal(faultId, store.DetailFaultId);
        Assert.Equal(stationId, store.DetailStationId);
    }

    [Theory]
    [InlineData(-1, 1, 25, 0)]
    [InlineData(0, 1, 25, 0)]
    [InlineData(1, 2, 25, 0)]
    [InlineData(1, 1, 24, 0)]
    public async Task Invalid_store_page_metadata_fails_closed(
        long totalCount, int returnedPage, int returnedPageSize, int itemCount)
    {
        var store = new ReadFakeStore
        {
            Page = new EquipmentFaultListPage(
                Enumerable.Range(0, itemCount).Select(_ => ValidListItem()).ToArray(),
                totalCount, returnedPage, returnedPageSize)
        };
        var service = new EquipmentFaultReadService(
            new ReadFakeAuthorization { Allowed = true }, store);

        var result = await service.GetPageAsync(
            Guid.NewGuid(), Guid.NewGuid(),
            new EquipmentFaultListQuery(1, 25, null, null, null, null));

        Assert.Equal(EquipmentFaultReadResultCode.DependencyFailure, result.Code);
        Assert.Null(result.Page);
    }

    [Fact]
    public async Task Duplicate_or_invalid_list_projection_is_rejected()
    {
        var duplicate = ValidListItem();
        var store = new ReadFakeStore
        {
            Page = new EquipmentFaultListPage(
                new[] { duplicate, duplicate }, 2, 1, 25)
        };
        var service = new EquipmentFaultReadService(
            new ReadFakeAuthorization { Allowed = true }, store);

        var result = await service.GetPageAsync(
            Guid.NewGuid(), Guid.NewGuid(),
            new EquipmentFaultListQuery(1, 25, null, null, null, null));

        Assert.Equal(EquipmentFaultReadResultCode.DependencyFailure, result.Code);
    }

    [Fact]
    public async Task Detail_with_matching_ids_but_invalid_projection_fails_closed()
    {
        var faultId = Guid.NewGuid();
        var stationId = Guid.NewGuid();
        var store = new ReadFakeStore
        {
            Detail = new EquipmentFaultDetail(
                faultId, stationId, Guid.Empty,
                "أجهزة", "مقياس", "وصف العطل التفصيلي",
                EquipmentFaultSeverity.High, EquipmentFaultStatus.Submitted,
                DateTimeOffset.UtcNow)
        };
        var service = new EquipmentFaultReadService(
            new ReadFakeAuthorization { Allowed = true }, store);

        var result = await service.GetDetailAsync(
            Guid.NewGuid(), stationId, faultId);

        Assert.Equal(EquipmentFaultReadResultCode.DependencyFailure, result.Code);
        Assert.Null(result.Detail);
    }

    [Fact]
    public async Task Empty_user_or_station_is_rejected_before_authorization_or_store()
    {
        var auth = new ReadFakeAuthorization { Allowed = true };
        var store = new ReadFakeStore();
        var service = new EquipmentFaultReadService(auth, store);
        var query = new EquipmentFaultListQuery(1, 25, null, null, null, null);

        var result = await service.GetPageAsync(Guid.Empty, Guid.NewGuid(), query);
        var emptyStation = await service.GetPageAsync(Guid.NewGuid(), Guid.Empty, query);

        Assert.Equal(EquipmentFaultReadResultCode.InvalidRequest, result.Code);
        Assert.Equal(EquipmentFaultReadResultCode.InvalidRequest, emptyStation.Code);
        Assert.Equal(0, auth.CallCount);
        Assert.Equal(0, store.ListCalls);
    }

    [Fact]
    public async Task Store_failure_fails_closed_and_caller_cancellation_propagates()
    {
        var store = new ReadFakeStore { ThrowFailure = true };
        var service = new EquipmentFaultReadService(
            new ReadFakeAuthorization { Allowed = true }, store);
        var query = new EquipmentFaultListQuery(1, 25, null, null, null, null);

        var failed = await service.GetPageAsync(Guid.NewGuid(), Guid.NewGuid(), query);
        Assert.Equal(EquipmentFaultReadResultCode.DependencyFailure, failed.Code);

        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        store.ThrowCancellation = true;
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            service.GetPageAsync(
                Guid.NewGuid(), Guid.NewGuid(), query, cancellation.Token));
    }

    private static EquipmentFaultListItem ValidListItem() =>
        new(Guid.NewGuid(), "أجهزة", "مقياس", EquipmentFaultSeverity.High,
            EquipmentFaultStatus.Submitted, DateTimeOffset.UtcNow);

    private sealed class ReadFakeAuthorization : IStationAuthorizationService
    {
        public bool Allowed { get; init; }
        public int CallCount { get; private set; }
        public string? Permission { get; private set; }
        public bool IsConfigured => true;

        public Task<bool> HasStationPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            Permission = permissionCode;
            return Task.FromResult(Allowed);
        }

        public Task<bool> HasStationOwnerAuthorityPermissionAsync(
            Guid userId, Guid stationId, string permissionCode,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(false);
    }

    private sealed class ReadFakeStore : IEquipmentFaultReadStore
    {
        public int ListCalls { get; private set; }
        public Guid? ListStationId { get; private set; }
        public EquipmentFaultListWindow? Window { get; private set; }
        public EquipmentFaultListSort? Sort { get; private set; }
        public EquipmentFaultDetail? Detail { get; init; }
        public EquipmentFaultListPage? Page { get; init; }
        public Guid? DetailFaultId { get; private set; }
        public Guid? DetailStationId { get; private set; }
        public bool ThrowFailure { get; set; }
        public bool ThrowCancellation { get; set; }

        public Task<EquipmentFaultListPage> GetPageAsync(
            Guid stationId, EquipmentFaultListQuery query,
            EquipmentFaultListWindow window, CancellationToken cancellationToken = default)
        {
            ListCalls++;
            ListStationId = stationId;
            Window = window;
            Sort = query.Sort;
            if (ThrowCancellation)
                throw new OperationCanceledException(cancellationToken);
            if (ThrowFailure)
                throw new InvalidOperationException("simulated read failure");
            return Task.FromResult(Page ?? new EquipmentFaultListPage(
                Array.Empty<EquipmentFaultListItem>(), 0, window.Page, window.PageSize));
        }

        public Task<EquipmentFaultDetail?> GetDetailAsync(
            Guid faultId, Guid stationId, CancellationToken cancellationToken = default)
        {
            DetailFaultId = faultId;
            DetailStationId = stationId;
            return Task.FromResult(Detail);
        }
    }
}
