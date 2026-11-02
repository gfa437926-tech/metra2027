using Metra.Api.Domain.Identity;
using Metra.Api.Features.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class MetraAccountDirectoryQueryServiceTests
{
    [Fact]
    public async Task Reads_page_with_server_actor_and_normalized_filters()
    {
        var store = new FakeStore(Page(Item("account-10"), Item("account-20")));
        var result = await Create("admin-1", store).ReadAsync(new(
            MetraAccountAccessState.Active, " station-1 ", " account- ", 20, "opaque"));
        Assert.True(result.Succeeded);
        Assert.Equal("admin-1", store.ActorId);
        Assert.Equal("station-1", store.Query?.StationId);
        Assert.Equal("account-", store.Query?.AccountIdPrefix);
        Assert.Equal(20, store.Query?.PageSize);
        Assert.Equal("opaque", store.Query?.Cursor);
        Assert.Equal(2, result.Page?.Items.Count);
    }

    [Fact]
    public async Task Rejects_missing_actor_without_store_access()
    {
        var store = new FakeStore(Page());
        var result = await Create(null, store).ReadAsync(new());
        Assert.Equal(MetraAccountDirectoryReadStatus.Unauthenticated, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Theory]
    [InlineData(" admin ")]
    [InlineData("admin\n")]
    [InlineData("admin/1")]
    public async Task Rejects_malformed_actor(string actorId)
    {
        var store = new FakeStore(Page());
        var result = await Create(actorId, store).ReadAsync(new());
        Assert.Equal(MetraAccountDirectoryReadStatus.Unauthorized, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(101)]
    public async Task Rejects_page_size_outside_bounds(int pageSize)
    {
        var store = new FakeStore(Page());
        var result = await Create("admin", store).ReadAsync(new(PageSize: pageSize));
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidQuery, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_null_query_undefined_state_and_malformed_filters()
    {
        var store = new FakeStore(Page());
        var service = Create("admin", store);
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidQuery, (await service.ReadAsync(null)).Status);
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidQuery,
            (await service.ReadAsync(new(State: (MetraAccountAccessState)999))).Status);
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidQuery,
            (await service.ReadAsync(new(StationId: "station\n1"))).Status);
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidQuery,
            (await service.ReadAsync(new(AccountIdPrefix: "account/"))).Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_oversized_or_control_character_cursor()
    {
        var store = new FakeStore(Page());
        var service = Create("admin", store);
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidQuery,
            (await service.ReadAsync(new(Cursor: new string('x', 2049)))).Status);
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidQuery,
            (await service.ReadAsync(new(Cursor: "cursor\r"))).Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_page_larger_than_requested()
    {
        var store = new FakeStore(Page(Item("account-1"), Item("account-2")));
        var result = await Create("admin", store).ReadAsync(new(PageSize: 1));
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_duplicate_or_non_ascending_account_ids()
    {
        var store = new FakeStore(Page(Item("account-1"), Item("account-1")));
        var service = Create("admin", store);
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidStoreResponse,
            (await service.ReadAsync(new())).Status);
        store.Page = Page(Item("account-2"), Item("account-1"));
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidStoreResponse,
            (await service.ReadAsync(new())).Status);
    }

    [Fact]
    public async Task Rejects_invalid_account_state_and_filter_leakage()
    {
        var store = new FakeStore(Page(Item("account-1") with { State = (MetraAccountAccessState)999 }));
        var service = Create("admin", store);
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidStoreResponse,
            (await service.ReadAsync(new())).Status);
        store.Page = Page(Item("account-1") with { State = MetraAccountAccessState.Suspended });
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidStoreResponse,
            (await service.ReadAsync(new(State: MetraAccountAccessState.Active))).Status);
        store.Page = Page(Item("other-account"));
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidStoreResponse,
            (await service.ReadAsync(new(AccountIdPrefix: "account-"))).Status);
    }

    [Fact]
    public async Task Rejects_malformed_store_identifiers()
    {
        var store = new FakeStore(Page(Item("account/1")));
        var result = await Create("admin", store).ReadAsync(new());
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_inconsistent_continuation_cursor()
    {
        var store = new FakeStore(new([Item("account-1")], true, null));
        var service = Create("admin", store);
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidStoreResponse,
            (await service.ReadAsync(new())).Status);
        store.Page = new([Item("account-1")], false, "unexpected");
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidStoreResponse,
            (await service.ReadAsync(new())).Status);
        store.Page = new([Item("account-1")], true, "same-cursor");
        Assert.Equal(MetraAccountDirectoryReadStatus.InvalidStoreResponse,
            (await service.ReadAsync(new(Cursor: "same-cursor"))).Status);
    }

    [Fact]
    public async Task Returns_empty_terminal_page_as_read_only_collection()
    {
        var result = await Create("admin", new FakeStore(Page())).ReadAsync(new());
        Assert.True(result.Succeeded);
        Assert.Empty(result.Page!.Items);
        Assert.False(result.Page.HasMore);
        Assert.Null(result.Page.NextCursor);
        var items = Assert.IsAssignableFrom<IList<MetraAccountDirectoryItem>>(result.Page.Items);
        Assert.True(items.IsReadOnly);
    }

    private static MetraAccountDirectoryItem Item(
        string id, MetraAccountAccessState state = MetraAccountAccessState.Active) => new(id, state);
    private static MetraAccountDirectoryStorePage Page(params MetraAccountDirectoryItem[] items)
        => new(items, false, null);
    private static MetraAccountDirectoryQueryService Create(string? actor, FakeStore store)
        => new(new FakeActorProvider(actor), store);

    private sealed class FakeActorProvider(string? actor) : IAccountLifecycleActorContextProvider
    {
        public Task<string?> GetCurrentActorUserIdAsync(CancellationToken cancellationToken)
            => Task.FromResult(actor);
    }

    private sealed class FakeStore(MetraAccountDirectoryStorePage page) : IMetraAccountDirectoryReadStore
    {
        public int Calls { get; private set; }
        public string? ActorId { get; private set; }
        public MetraAccountDirectoryQuery? Query { get; private set; }
        public MetraAccountDirectoryStorePage Page { get; set; } = page;
        public Task<MetraAccountDirectoryStorePage> ReadPageAsync(
            string actorUserId, MetraAccountDirectoryQuery normalizedQuery,
            CancellationToken cancellationToken)
        {
            Calls++;
            ActorId = actorUserId;
            Query = normalizedQuery;
            return Task.FromResult(Page);
        }
    }
}
