using Metra.Api.Features.Identity;
using Metra.Api.Features.Stations;
using Xunit;

namespace Metra.Api.Tests.Features.Stations;

public sealed class StationCatalogueQueryServiceTests
{
    [Fact]
    public async Task Returns_classic_and_automatic_records_without_merging_sources()
    {
        var classic = Item(StationCatalogueSourceKind.Classic, "12", "دمشق");
        var automatic = Item(StationCatalogueSourceKind.Automatic, "12", "دمشق");
        var store = new FakeStore(Page(classic, automatic));
        var result = await Create("admin-1", store).ReadAsync(new());

        Assert.True(result.Succeeded);
        Assert.Equal(2, result.Page!.Items.Count);
        Assert.NotEqual(result.Page.Items[0].SourceKind, result.Page.Items[1].SourceKind);
        Assert.Equal("12", result.Page.Items[0].SourceRecordId);
        Assert.Equal("12", result.Page.Items[1].SourceRecordId);
    }

    [Fact]
    public async Task Passes_server_actor_and_normalized_query_to_store()
    {
        var store = new FakeStore(Page(Item(StationCatalogueSourceKind.Classic, "1", "دمشق")));
        var result = await Create("admin-1", store).ReadAsync(
            new(StationCatalogueSourceKind.Classic, " دمشق ", 25, "opaque"));

        Assert.True(result.Succeeded);
        Assert.Equal("admin-1", store.ActorId);
        Assert.Equal(StationCatalogueSourceKind.Classic, store.Query!.SourceKind);
        Assert.Equal("دمشق", store.Query.NamePrefix);
        Assert.Equal(25, store.Query.PageSize);
        Assert.Equal("opaque", store.Query.Cursor);
    }

    [Fact]
    public async Task Allows_missing_coordinates_and_preserves_optional_metadata()
    {
        var item = Item(StationCatalogueSourceKind.Classic, "7", "الإدارة العامة") with
        {
            Latitude = null,
            Longitude = null,
            SourceStationType = null,
            SourceCode = null,
            ElevationMetres = null
        };
        var result = await Create("admin", new FakeStore(Page(item))).ReadAsync(new());
        Assert.True(result.Succeeded);
        Assert.Null(result.Page!.Items[0].Latitude);
        Assert.Null(result.Page.Items[0].Longitude);
    }

    [Fact]
    public async Task Rejects_missing_actor_without_store_access()
    {
        var store = new FakeStore(Page());
        var result = await Create(null, store).ReadAsync(new());
        Assert.Equal(StationCatalogueReadStatus.Unauthenticated, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Theory]
    [InlineData(" admin ")]
    [InlineData("admin\n")]
    [InlineData("admin/1")]
    public async Task Rejects_malformed_actor(string actor)
    {
        var store = new FakeStore(Page());
        var result = await Create(actor, store).ReadAsync(new());
        Assert.Equal(StationCatalogueReadStatus.Unauthorized, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_invalid_query_enum_page_size_and_prefix()
    {
        var store = new FakeStore(Page());
        var service = Create("admin", store);
        Assert.Equal(StationCatalogueReadStatus.InvalidQuery, (await service.ReadAsync(null)).Status);
        Assert.Equal(StationCatalogueReadStatus.InvalidQuery,
            (await service.ReadAsync(new((StationCatalogueSourceKind)99))).Status);
        Assert.Equal(StationCatalogueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(PageSize: 0))).Status);
        Assert.Equal(StationCatalogueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(PageSize: 101))).Status);
        Assert.Equal(StationCatalogueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(NamePrefix: "  \n "))).Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_invalid_cursor()
    {
        var store = new FakeStore(Page());
        var service = Create("admin", store);
        Assert.Equal(StationCatalogueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(Cursor: new string('x', 2049)))).Status);
        Assert.Equal(StationCatalogueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(Cursor: "bad\r"))).Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_c1_control_characters_in_query_and_store_response()
    {
        var store = new FakeStore(Page());
        var service = Create("admin", store);

        Assert.Equal(StationCatalogueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(NamePrefix: "محطة\\u0085"))).Status);
        Assert.Equal(StationCatalogueReadStatus.InvalidQuery,
            (await service.ReadAsync(new(Cursor: "cursor\\u009f"))).Status);
        Assert.Equal(0, store.Calls);

        var malformedName = Item(StationCatalogueSourceKind.Classic, "1", "محطة\\u0085");
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse,
            (await Create("admin", new FakeStore(Page(malformedName))).ReadAsync(new())).Status);

        var malformedMetadata = Item(StationCatalogueSourceKind.Classic, "1", "محطة") with
        {
            SourceCode = "code\\u009f"
        };
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse,
            (await Create("admin", new FakeStore(Page(malformedMetadata))).ReadAsync(new())).Status);
    }

    [Fact]
    public async Task Rejects_source_filter_leakage_and_undefined_source_kind()
    {
        var store = new FakeStore(Page(Item(StationCatalogueSourceKind.Automatic, "1", "محطة")));
        var result = await Create("admin", store).ReadAsync(
            new(SourceKind: StationCatalogueSourceKind.Classic));
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse, result.Status);

        store.Page = Page(Item((StationCatalogueSourceKind)77, "2", "محطة"));
        result = await Create("admin", store).ReadAsync(new());
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse, result.Status);
    }

    [Theory]
    [InlineData(-91, 20)]
    [InlineData(91, 20)]
    [InlineData(10, -181)]
    [InlineData(10, 181)]
    public async Task Rejects_out_of_range_coordinates(decimal latitude, decimal longitude)
    {
        var item = Item(StationCatalogueSourceKind.Classic, "1", "محطة") with
        {
            Latitude = latitude,
            Longitude = longitude
        };
        var result = await Create("admin", new FakeStore(Page(item))).ReadAsync(new());
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_partial_coordinate_pair()
    {
        var item = Item(StationCatalogueSourceKind.Classic, "1", "محطة") with
        {
            Latitude = 33m,
            Longitude = null
        };
        var result = await Create("admin", new FakeStore(Page(item))).ReadAsync(new());
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_duplicate_source_identity_but_allows_same_id_across_sources()
    {
        var classic = Item(StationCatalogueSourceKind.Classic, "1", "أ");
        var duplicate = Item(StationCatalogueSourceKind.Classic, "1", "ب");
        var result = await Create("admin", new FakeStore(Page(classic, duplicate))).ReadAsync(new());
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse, result.Status);

        var automatic = Item(StationCatalogueSourceKind.Automatic, "1", "أ");
        result = await Create("admin", new FakeStore(Page(classic, automatic))).ReadAsync(new());
        Assert.True(result.Succeeded);
    }

    [Fact]
    public async Task Rejects_out_of_order_source_records()
    {
        var result = await Create("admin", new FakeStore(Page(
            Item(StationCatalogueSourceKind.Classic, "2", "أ"),
            Item(StationCatalogueSourceKind.Classic, "1", "ب")))).ReadAsync(new());
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_malformed_source_ids_and_display_names()
    {
        var service = Create("admin", new FakeStore(Page(Item(
            StationCatalogueSourceKind.Classic, "bad/id", "محطة"))));
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse, (await service.ReadAsync(new())).Status);

        service = Create("admin", new FakeStore(Page(Item(
            StationCatalogueSourceKind.Classic, "2", " \n "))));
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse, (await service.ReadAsync(new())).Status);
    }

    [Fact]
    public async Task Rejects_malformed_metadata_and_elevation()
    {
        var item = Item(StationCatalogueSourceKind.Classic, "1", "محطة") with
        {
            SourceCode = "bad\ncode",
            ElevationMetres = 10001m
        };
        var result = await Create("admin", new FakeStore(Page(item))).ReadAsync(new());
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_page_overflow_duplicate_cursor_and_bad_continuation()
    {
        var store = new FakeStore(Page(
            Item(StationCatalogueSourceKind.Classic, "1", "أ"),
            Item(StationCatalogueSourceKind.Classic, "2", "ب")));
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse,
            (await Create("admin", store).ReadAsync(new(PageSize: 1))).Status);

        store.Page = new([Item(StationCatalogueSourceKind.Classic, "1", "أ")], true, null);
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse,
            (await Create("admin", store).ReadAsync(new())).Status);

        store.Page = new([Item(StationCatalogueSourceKind.Classic, "1", "أ")], true, "same");
        Assert.Equal(StationCatalogueReadStatus.InvalidStoreResponse,
            (await Create("admin", store).ReadAsync(new(Cursor: "same"))).Status);
    }

    [Fact]
    public async Task Returns_read_only_page()
    {
        var result = await Create("admin", new FakeStore(Page(
            Item(StationCatalogueSourceKind.Classic, "1", "أ")))).ReadAsync(new());
        Assert.True(result.Succeeded);
        var items = Assert.IsAssignableFrom<IList<StationCatalogueItem>>(result.Page!.Items);
        Assert.True(items.IsReadOnly);
    }

    private static StationCatalogueItem Item(
        StationCatalogueSourceKind kind, string id, string name)
        => new(kind, id, name, null, null, 33m, 36m, null);

    private static StationCatalogueStorePage Page(params StationCatalogueItem[] items)
        => new(items, false, null);

    private static StationCatalogueQueryService Create(string? actor, FakeStore store)
        => new(new FakeActorProvider(actor), store);

    private sealed class FakeActorProvider(string? actor) : IAccountLifecycleActorContextProvider
    {
        public Task<string?> GetCurrentActorUserIdAsync(CancellationToken cancellationToken)
            => Task.FromResult(actor);
    }

    private sealed class FakeStore(StationCatalogueStorePage page) : IStationCatalogueReadStore
    {
        public int Calls { get; private set; }
        public string? ActorId { get; private set; }
        public StationCatalogueQuery? Query { get; private set; }
        public StationCatalogueStorePage Page { get; set; } = page;

        public Task<StationCatalogueStorePage> ReadPageAsync(
            string actorUserId, StationCatalogueQuery normalizedQuery,
            CancellationToken cancellationToken)
        {
            Calls++;
            ActorId = actorUserId;
            Query = normalizedQuery;
            return Task.FromResult(Page);
        }
    }
}
