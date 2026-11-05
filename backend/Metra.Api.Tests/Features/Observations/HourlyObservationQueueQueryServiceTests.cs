using Metra.Api.Features.Observations;
using Xunit;

namespace Metra.Api.Tests.Features.Observations;

public sealed class HourlyObservationQueueQueryServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 11, 5, 12, 0, 0, TimeSpan.Zero);

    private static readonly string ActorId = "00000000-0000-0000-0000-000000000001";
    private static readonly string StationA = "00000000-0000-0000-0000-000000000010";
    private static readonly string StationB = "00000000-0000-0000-0000-000000000020";
    private static readonly string ObservationA = "10000000-0000-0000-0000-000000000001";
    private static readonly string ObservationB = "10000000-0000-0000-0000-000000000002";
    private static readonly string SubmitterId = "20000000-0000-0000-0000-000000000001";

    [Fact]
    public async Task Reads_bounded_queue_with_server_actor_and_normalized_station_filter()
    {
        var store = new FakeStore(Page(Item(ObservationB, StationA, Now), Item(ObservationA, StationA, Now.AddMinutes(-1))));
        var service = Create(Actor(Grant(StationA), Grant(StationB)), store);

        var result = await service.ReadAsync(new(" " + StationA.ToUpperInvariant() + " ", 25, "opaque-cursor"));

        Assert.True(result.Succeeded);
        Assert.Equal(HourlyObservationQueueReadStatus.Succeeded, result.Status);
        Assert.Equal(ActorId, store.Actor?.UserId);
        Assert.Equal(StationA, store.Query?.StationId);
        Assert.Equal(25, store.Query?.PageSize);
        Assert.Equal("opaque-cursor", store.Query?.Cursor);
        Assert.Equal(2, result.Page?.Items.Count);
    }

    [Fact]
    public async Task Reads_all_effectively_assigned_stations_when_filter_is_omitted()
    {
        var store = new FakeStore(Page(Item(ObservationB, StationB, Now), Item(ObservationA, StationA, Now.AddMinutes(-1))));
        var result = await Create(Actor(Grant(StationA), Grant(StationB)), store).ReadAsync(new());

        Assert.True(result.Succeeded);
        Assert.Null(store.Query?.StationId);
        Assert.Equal(2, result.Page?.Items.Count);
    }

    [Fact]
    public async Task Rejects_missing_actor_before_store_access()
    {
        var store = new FakeStore(Page());
        var result = await Create(null, store).ReadAsync(new());

        Assert.Equal(HourlyObservationQueueReadStatus.Unauthenticated, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_inactive_actor_or_actor_without_review_permission()
    {
        var store = new FakeStore(Page());

        var inactive = Actor(Grant(StationA)) with { IsActive = false };
        var result = await Create(inactive, store).ReadAsync(new());
        Assert.Equal(HourlyObservationQueueReadStatus.Unauthorized, result.Status);

        var noPermission = Actor(Grant(StationA)) with
        {
            Permissions = new HashSet<string>(StringComparer.Ordinal)
        };
        result = await Create(noPermission, store).ReadAsync(new());
        Assert.Equal(HourlyObservationQueueReadStatus.Unauthorized, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(101)]
    public async Task Rejects_page_size_outside_bounds(int pageSize)
    {
        var store = new FakeStore(Page());
        var result = await Create(Actor(Grant(StationA)), store).ReadAsync(new(PageSize: pageSize));

        Assert.Equal(HourlyObservationQueueReadStatus.InvalidQuery, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_malformed_station_and_cursor_before_store_access()
    {
        var store = new FakeStore(Page());
        var service = Create(Actor(Grant(StationA)), store);

        Assert.Equal(HourlyObservationQueueReadStatus.InvalidQuery,
            (await service.ReadAsync(new("not-a-guid"))).Status);
        Assert.Equal(HourlyObservationQueueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(Cursor: new string('x', 2049)))).Status);
        Assert.Equal(HourlyObservationQueueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(Cursor: "bad\r-cursor"))).Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_station_outside_actor_scope()
    {
        var store = new FakeStore(Page());
        var result = await Create(Actor(Grant(StationA)), store).ReadAsync(new(StationB));

        Assert.Equal(HourlyObservationQueueReadStatus.Unauthorized, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_actor_without_effective_station_assignments()
    {
        var expired = new HourlyObservationStationGrant(
            StationA, Now.AddDays(-2), Now.AddMinutes(-1), null);
        var store = new FakeStore(Page());
        var result = await Create(Actor(expired), store).ReadAsync(new());

        Assert.Equal(HourlyObservationQueueReadStatus.Unauthorized, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_store_rows_outside_actor_station_scope()
    {
        var store = new FakeStore(Page(Item(ObservationA, StationB, Now)));
        var result = await Create(Actor(Grant(StationA)), store).ReadAsync(new());

        Assert.Equal(HourlyObservationQueueReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_duplicate_or_ascending_rows()
    {
        var item = Item(ObservationA, StationA, Now);
        var store = new FakeStore(Page(item, item));
        var service = Create(Actor(Grant(StationA)), store);
        Assert.Equal(HourlyObservationQueueReadStatus.InvalidStoreResponse,
            (await service.ReadAsync(new())).Status);

        store.Page = Page(
            Item(ObservationA, StationA, Now.AddMinutes(-1)),
            Item(ObservationB, StationA, Now));
        Assert.Equal(HourlyObservationQueueReadStatus.InvalidStoreResponse,
            (await service.ReadAsync(new())).Status);
    }

    [Fact]
    public async Task Returns_read_only_queue_projection()
    {
        var store = new FakeStore(Page(Item(ObservationA, StationA, Now)));
        var result = await Create(Actor(Grant(StationA)), store).ReadAsync(new());

        Assert.True(result.Succeeded);
        Assert.False(result.Page!.HasMore);
        Assert.Null(result.Page.NextCursor);
        var readOnly = Assert.IsAssignableFrom<IList<HourlyObservationQueueItem>>(result.Page.Items);
        Assert.True(readOnly.IsReadOnly);
    }

    private static HourlyObservationActorContext Actor(params HourlyObservationStationGrant[] grants)
        => new(
            ActorId,
            true,
            grants,
            new HashSet<string>(StringComparer.Ordinal)
            {
                HourlyObservationApplicationService.ReviewPermission
            });

    private static HourlyObservationStationGrant Grant(string stationId)
        => new(stationId, Now.AddDays(-1), null, null);

    private static HourlyObservationQueueItem Item(
        string id,
        string stationId,
        DateTimeOffset submittedAt)
        => new(id, stationId, new DateOnly(2026, 11, 5), 9, SubmitterId, submittedAt);

    private static HourlyObservationQueueStorePage Page(params HourlyObservationQueueItem[] items)
        => new(items, false, null);

    private static HourlyObservationQueueQueryService Create(
        HourlyObservationActorContext? actor,
        FakeStore store)
        => new(new FakeActorProvider(actor), store, new FixedTimeProvider(Now));

    private sealed class FakeActorProvider(HourlyObservationActorContext? actor)
        : IHourlyObservationActorContextProvider
    {
        public Task<HourlyObservationActorContext?> GetCurrentActorAsync(CancellationToken cancellationToken)
            => Task.FromResult(actor);
    }

    private sealed class FakeStore(HourlyObservationQueueStorePage page)
        : IHourlyObservationQueueReadStore
    {
        public int Calls { get; private set; }
        public HourlyObservationActorContext? Actor { get; private set; }
        public HourlyObservationQueueQuery? Query { get; private set; }
        public HourlyObservationQueueStorePage Page { get; set; } = page;

        public Task<HourlyObservationQueueStorePage> ReadPageAsync(
            HourlyObservationActorContext actor,
            HourlyObservationQueueQuery normalizedQuery,
            CancellationToken cancellationToken)
        {
            Calls++;
            Actor = actor;
            Query = normalizedQuery;
            return Task.FromResult(Page);
        }
    }

    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
