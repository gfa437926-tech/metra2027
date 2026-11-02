using Metra.Api.Features.Identity;
using Metra.Api.Features.Stations;
using Xunit;

namespace Metra.Api.Tests.Features.Stations;

public sealed class StationDetailQueryServiceTests
{
    [Fact]
    public async Task Reads_exact_source_qualified_record_with_server_actor()
    {
        var key = new StationSourceKey(StationCatalogueSourceKind.Automatic, "station-7");
        var station = Item(key.SourceKind, key.SourceRecordId);
        var store = new FakeStore(station);
        var result = await Create("admin-1", store).ReadAsync(key);

        Assert.True(result.Succeeded);
        Assert.Equal(station, result.Station);
        Assert.Equal("admin-1", store.ActorId);
        Assert.Equal(key, store.Key);
        Assert.Equal(1, store.Calls);
    }

    [Fact]
    public async Task Does_not_fallback_to_other_source_kind_with_same_local_id()
    {
        var key = new StationSourceKey(StationCatalogueSourceKind.Automatic, "station-7");
        var store = new FakeStore(Item(StationCatalogueSourceKind.Classic, "station-7"));
        var result = await Create("admin", store).ReadAsync(key);

        Assert.Equal(StationDetailReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Returns_not_found_for_missing_or_out_of_scope_store_result()
    {
        var store = new FakeStore(null);
        var result = await Create("admin", store).ReadAsync(
            new(StationCatalogueSourceKind.Classic, "station-1"));
        Assert.Equal(StationDetailReadStatus.NotFound, result.Status);
        Assert.Null(result.Station);
    }

    [Fact]
    public async Task Rejects_missing_actor_without_store_access()
    {
        var store = new FakeStore(Item(StationCatalogueSourceKind.Classic, "station-1"));
        var result = await Create(null, store).ReadAsync(
            new(StationCatalogueSourceKind.Classic, "station-1"));
        Assert.Equal(StationDetailReadStatus.Unauthenticated, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Theory]
    [InlineData(" admin ")]
    [InlineData("admin\n")]
    [InlineData("admin/1")]
    public async Task Rejects_malformed_actor(string actor)
    {
        var store = new FakeStore(null);
        var result = await Create(actor, store).ReadAsync(
            new(StationCatalogueSourceKind.Classic, "station-1"));
        Assert.Equal(StationDetailReadStatus.Unauthorized, result.Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_invalid_source_kind_and_source_identifier()
    {
        var store = new FakeStore(null);
        var service = Create("admin", store);

        Assert.Equal(StationDetailReadStatus.InvalidKey,
            (await service.ReadAsync(null)).Status);
        Assert.Equal(StationDetailReadStatus.InvalidKey,
            (await service.ReadAsync(new((StationCatalogueSourceKind)77, "station-1"))).Status);
        Assert.Equal(StationDetailReadStatus.InvalidKey,
            (await service.ReadAsync(new(StationCatalogueSourceKind.Classic, "bad/id"))).Status);
        Assert.Equal(StationDetailReadStatus.InvalidKey,
            (await service.ReadAsync(new(StationCatalogueSourceKind.Classic, " "))).Status);
        Assert.Equal(StationDetailReadStatus.InvalidKey,
            (await service.ReadAsync(new(StationCatalogueSourceKind.Classic, new string('x', 129)))).Status);
        Assert.Equal(0, store.Calls);
    }

    [Fact]
    public async Task Rejects_store_record_with_different_source_identifier()
    {
        var store = new FakeStore(Item(StationCatalogueSourceKind.Classic, "station-2"));
        var result = await Create("admin", store).ReadAsync(
            new(StationCatalogueSourceKind.Classic, "station-1"));
        Assert.Equal(StationDetailReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Allows_missing_coordinates_and_optional_source_metadata()
    {
        var station = Item(StationCatalogueSourceKind.Classic, "station-1") with
        {
            Latitude = null,
            Longitude = null,
            SourceStationType = null,
            SourceCode = null,
            ElevationMetres = null
        };
        var result = await Create("admin", new FakeStore(station)).ReadAsync(
            new(StationCatalogueSourceKind.Classic, "station-1"));

        Assert.True(result.Succeeded);
        Assert.Null(result.Station!.Latitude);
        Assert.Null(result.Station.Longitude);
        Assert.Null(result.Station.SourceStationType);
    }

    [Theory]
    [InlineData(-91, 20)]
    [InlineData(91, 20)]
    [InlineData(10, -181)]
    [InlineData(10, 181)]
    public async Task Rejects_invalid_coordinates(decimal latitude, decimal longitude)
    {
        var station = Item(StationCatalogueSourceKind.Classic, "station-1") with
        {
            Latitude = latitude,
            Longitude = longitude
        };
        var result = await Create("admin", new FakeStore(station)).ReadAsync(
            new(StationCatalogueSourceKind.Classic, "station-1"));
        Assert.Equal(StationDetailReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_partial_coordinates_and_invalid_metadata()
    {
        var station = Item(StationCatalogueSourceKind.Classic, "station-1") with
        {
            Latitude = 33m,
            Longitude = null
        };
        var result = await Create("admin", new FakeStore(station)).ReadAsync(
            new(StationCatalogueSourceKind.Classic, "station-1"));
        Assert.Equal(StationDetailReadStatus.InvalidStoreResponse, result.Status);

        station = Item(StationCatalogueSourceKind.Classic, "station-1") with
        {
            SourceCode = "bad\ncode"
        };
        result = await Create("admin", new FakeStore(station)).ReadAsync(
            new(StationCatalogueSourceKind.Classic, "station-1"));
        Assert.Equal(StationDetailReadStatus.InvalidStoreResponse, result.Status);

        station = Item(StationCatalogueSourceKind.Classic, "station-1") with
        {
            ElevationMetres = 10001m
        };
        result = await Create("admin", new FakeStore(station)).ReadAsync(
            new(StationCatalogueSourceKind.Classic, "station-1"));
        Assert.Equal(StationDetailReadStatus.InvalidStoreResponse, result.Status);
    }

    [Fact]
    public async Task Rejects_blank_and_control_character_display_names()
    {
        var station = Item(StationCatalogueSourceKind.Classic, "station-1") with
        {
            DisplayName = " \n "
        };
        var result = await Create("admin", new FakeStore(station)).ReadAsync(
            new(StationCatalogueSourceKind.Classic, "station-1"));
        Assert.Equal(StationDetailReadStatus.InvalidStoreResponse, result.Status);
    }

    private static StationCatalogueItem Item(StationCatalogueSourceKind kind, string id)
        => new(kind, id, "محطة اختبار", "classic", "SRC-1", 33m, 36m, 700m);

    private static StationDetailQueryService Create(string? actor, FakeStore store)
        => new(new FakeActorProvider(actor), store);

    private sealed class FakeActorProvider(string? actor) : IAccountLifecycleActorContextProvider
    {
        public Task<string?> GetCurrentActorUserIdAsync(CancellationToken cancellationToken)
            => Task.FromResult(actor);
    }

    private sealed class FakeStore(StationCatalogueItem? station) : IStationDetailReadStore
    {
        public int Calls { get; private set; }
        public string? ActorId { get; private set; }
        public StationSourceKey? Key { get; private set; }

        public Task<StationCatalogueItem?> ReadAsync(
            string actorUserId, StationSourceKey key, CancellationToken cancellationToken)
        {
            Calls++;
            ActorId = actorUserId;
            Key = key;
            return Task.FromResult(station);
        }
    }
}
