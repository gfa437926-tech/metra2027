using Metra.Api.Domain.Identity;
using Metra.Api.Features.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class RegistrationApprovalQueueQueryServiceTests
{
    private static readonly DateTimeOffset Newest =
        new(2026, 11, 2, 8, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Reads_bounded_queue_with_server_resolved_actor_and_normalized_filters()
    {
        var actor = Actor();
        var store = new FakeStore(Page(Item("req-2", Newest), Item("req-1", Newest.AddMinutes(-1))));
        var service = Create(actor, store);

        var result = await service.ReadAsync(new(
            RegistrationApprovalStatus.PendingStationApproval,
            " station-1 ",
            25,
            "opaque-cursor"));

        Assert.True(result.Succeeded);
        Assert.Equal(RegistrationApprovalQueueReadStatus.Succeeded, result.Status);
        Assert.Equal("approver-1", store.Actor?.UserId);
        Assert.Equal("station-1", store.Query?.StationId);
        Assert.Equal(25, store.Query?.PageSize);
        Assert.Equal("opaque-cursor", store.Query?.Cursor);
        Assert.Equal(2, result.Page?.Items.Count);
    }

    [Fact]
    public async Task Rejects_missing_actor_before_store_access()
    {
        var store = new FakeStore(Page());
        var service = Create(null, store);

        var result = await service.ReadAsync(new());

        Assert.Equal(RegistrationApprovalQueueReadStatus.Unauthenticated, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_inactive_or_unprivileged_actor()
    {
        var inactive = Actor() with { IsActive = false };
        var store = new FakeStore(Page());
        var result = await Create(inactive, store).ReadAsync(new());
        Assert.Equal(RegistrationApprovalQueueReadStatus.Unauthorized, result.Status);
        Assert.Equal(0, store.Calls);

        var unprivileged = Actor() with
        {
            CanApproveStationRegistrations = false,
            CanApproveSystemRegistrations = false
        };
        result = await Create(unprivileged, store).ReadAsync(new());
        Assert.Equal(RegistrationApprovalQueueReadStatus.Unauthorized, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(101)]
    public async Task Rejects_page_size_outside_bounds(int pageSize)
    {
        var store = new FakeStore(Page());
        var result = await Create(Actor(), store).ReadAsync(new(PageSize: pageSize));
        Assert.Equal(RegistrationApprovalQueueReadStatus.InvalidQuery, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_undefined_status_and_malformed_station_filter()
    {
        var store = new FakeStore(Page());
        var service = Create(Actor(), store);

        Assert.Equal(
            RegistrationApprovalQueueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(Status: (RegistrationApprovalStatus)999))).Status);
        Assert.Equal(
            RegistrationApprovalQueueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(StationId: "station\n1"))).Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_oversized_or_control_character_cursor()
    {
        var store = new FakeStore(Page());
        var service = Create(Actor(), store);

        Assert.Equal(
            RegistrationApprovalQueueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(Cursor: new string('x', 2049)))).Status);
        Assert.Equal(
            RegistrationApprovalQueueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(Cursor: "cursor\r"))).Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_malformed_actor_scope_before_store_access()
    {
        var actor = Actor() with
        {
            StationManagerStationIds = new HashSet<string> { " station-1 " }
        };
        var store = new FakeStore(Page());

        var result = await Create(actor, store).ReadAsync(new());

        Assert.Equal(RegistrationApprovalQueueReadStatus.Unauthorized, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_store_page_larger_than_requested_page_size()
    {
        var store = new FakeStore(Page(Item("req-2", Newest), Item("req-1", Newest.AddMinutes(-1))));
        var result = await Create(Actor(), store).ReadAsync(new(PageSize: 1));
        Assert.Equal(RegistrationApprovalQueueReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_duplicate_request_identifiers()
    {
        var item = Item("req-1", Newest);
        var store = new FakeStore(Page(item, item));
        var result = await Create(Actor(), store).ReadAsync(new());
        Assert.Equal(RegistrationApprovalQueueReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_non_deterministic_or_ascending_order()
    {
        var store = new FakeStore(Page(
            Item("req-1", Newest.AddMinutes(-1)),
            Item("req-2", Newest)));
        var result = await Create(Actor(), store).ReadAsync(new());
        Assert.Equal(RegistrationApprovalQueueReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Uses_request_id_as_descending_tie_breaker()
    {
        var store = new FakeStore(Page(
            Item("req-b", Newest),
            Item("req-a", Newest)));
        var result = await Create(Actor(), store).ReadAsync(new());
        Assert.True(result.Succeeded);
    }

    [Fact]
    public async Task Rejects_missing_or_unexpected_continuation_cursor()
    {
        var store = new FakeStore(new([Item("req-1", Newest)], true, null));
        var result = await Create(Actor(), store).ReadAsync(new());
        Assert.Equal(RegistrationApprovalQueueReadStatus.InvalidStoreResponse, result.Status);

        store.Page = new([Item("req-1", Newest)], false, "unexpected");
        result = await Create(Actor(), store).ReadAsync(new());
        Assert.Equal(RegistrationApprovalQueueReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_non_utc_timestamps_and_noncanonical_codes()
    {
        var local = new DateTimeOffset(2026, 11, 2, 8, 0, 0, TimeSpan.FromHours(3));
        var store = new FakeStore(Page(Item("req-1", local)));
        var result = await Create(Actor(), store).ReadAsync(new());
        Assert.Equal(RegistrationApprovalQueueReadStatus.InvalidStoreResponse, result.Status);

        store.Page = Page(Item("req-1", Newest) with { RequestedRoleCode = "Observer" });
        result = await Create(Actor(), store).ReadAsync(new());
        Assert.Equal(RegistrationApprovalQueueReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Returns_terminal_empty_page_and_read_only_projection()
    {
        var store = new FakeStore(Page());
        var result = await Create(Actor(), store).ReadAsync(new());

        Assert.True(result.Succeeded);
        Assert.Empty(result.Page!.Items);
        Assert.False(result.Page.HasMore);
        Assert.Null(result.Page.NextCursor);
        Assert.IsNotType<List<RegistrationApprovalQueueItem>>(result.Page.Items);
        var readOnly = Assert.IsAssignableFrom<IList<RegistrationApprovalQueueItem>>(result.Page.Items);
        Assert.True(readOnly.IsReadOnly);
    }

    private static RegistrationApprovalActorContext Actor()
        => new("approver-1", true, true, new HashSet<string> { "station-1" }, false);

    private static RegistrationApprovalQueueItem Item(string id, DateTimeOffset submittedAt)
        => new(id, "applicant-1", "station-1", "observer", 
            RegistrationApprovalStatus.PendingStationApproval, submittedAt);

    private static RegistrationApprovalQueueStorePage Page(
        params RegistrationApprovalQueueItem[] items)
        => new(items, false, null);

    private static RegistrationApprovalQueueQueryService Create(
        RegistrationApprovalActorContext? actor,
        FakeStore store)
        => new(new FakeActorProvider(actor), store);

    private sealed class FakeActorProvider(RegistrationApprovalActorContext? actor)
        : IRegistrationApprovalActorContextProvider
    {
        public Task<RegistrationApprovalActorContext?> GetCurrentActorAsync(
            CancellationToken cancellationToken)
            => Task.FromResult(actor);
    }

    private sealed class FakeStore(RegistrationApprovalQueueStorePage page)
        : IRegistrationApprovalQueueReadStore
    {
        public int Calls { get; private set; }
        public RegistrationApprovalActorContext? Actor { get; private set; }
        public RegistrationApprovalQueueQuery? Query { get; private set; }
        public RegistrationApprovalQueueStorePage Page { get; set; } = page;

        public Task<RegistrationApprovalQueueStorePage> ReadPageAsync(
            RegistrationApprovalActorContext actor,
            RegistrationApprovalQueueQuery normalizedQuery,
            CancellationToken cancellationToken)
        {
            Calls++;
            Actor = actor;
            Query = normalizedQuery;
            return Task.FromResult(Page);
        }
    }
}

