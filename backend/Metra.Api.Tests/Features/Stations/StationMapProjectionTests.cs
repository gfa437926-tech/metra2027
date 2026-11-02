using Metra.Api.Features.Stations;
using Xunit;

namespace Metra.Api.Tests.Features.Stations;

public sealed class StationMapProjectionTests
{
    [Fact]
    public void Projects_classic_and_automatic_stations_into_one_marker_collection()
    {
        var stations = new[]
        {
            Item(StationCatalogueSourceKind.Classic, "1", "دمشق", 33.5m, 36.3m),
            Item(StationCatalogueSourceKind.Automatic, "1", "دمشق", 33.6m, 36.4m)
        };

        var result = StationMapProjection.Create(stations);

        Assert.Equal(2, result.Markers.Count);
        Assert.Empty(result.WithoutCoordinates);
        Assert.NotEqual(result.Markers[0].SourceQualifiedKey, result.Markers[1].SourceQualifiedKey);
        Assert.Equal(StationCatalogueSourceKind.Classic, result.Markers[0].SourceKind);
        Assert.Equal(StationCatalogueSourceKind.Automatic, result.Markers[1].SourceKind);
    }

    [Fact]
    public void Keeps_stations_without_coordinates_in_separate_list_instead_of_fabricating_markers()
    {
        var located = Item(StationCatalogueSourceKind.Automatic, "2", "محطة آلية", 34m, 37m);
        var unlocated = Item(StationCatalogueSourceKind.Classic, "3", "محطة كلاسيكية", null, null);

        var result = StationMapProjection.Create([located, unlocated]);

        Assert.Single(result.Markers);
        Assert.Single(result.WithoutCoordinates);
        Assert.Equal("3", result.WithoutCoordinates[0].SourceRecordId);
        Assert.Equal(34m, result.Markers[0].Latitude);
        Assert.Equal(37m, result.Markers[0].Longitude);
    }

    [Fact]
    public void Does_not_drop_unlocated_records_when_all_stations_are_unlocated()
    {
        var result = StationMapProjection.Create([
            Item(StationCatalogueSourceKind.Classic, "1", "أ", null, null),
            Item(StationCatalogueSourceKind.Classic, "2", "ب", null, null)
        ]);

        Assert.Empty(result.Markers);
        Assert.Equal(2, result.WithoutCoordinates.Count);
    }

    [Theory]
    [InlineData(91, 30)]
    [InlineData(30, 181)]
    public void Rejects_out_of_range_coordinates(decimal latitude, decimal longitude)
    {
        Assert.Throws<ArgumentException>(() => StationMapProjection.Create([
            Item(StationCatalogueSourceKind.Classic, "1", "محطة", latitude, longitude)
        ]));
    }

    [Fact]
    public void Rejects_partial_coordinate_pair()
    {
        Assert.Throws<ArgumentException>(() => StationMapProjection.Create([
            Item(StationCatalogueSourceKind.Classic, "1", "محطة", 33m, null)
        ]));
    }

    [Fact]
    public void Rejects_duplicate_source_qualified_identity()
    {
        var station = Item(StationCatalogueSourceKind.Classic, "1", "محطة", 33m, 36m);
        Assert.Throws<ArgumentException>(() => StationMapProjection.Create([station, station]));
    }

    [Fact]
    public void Returns_read_only_collections()
    {
        var result = StationMapProjection.Create([
            Item(StationCatalogueSourceKind.Classic, "1", "محطة", null, null)
        ]);

        Assert.True(Assert.IsAssignableFrom<IList<StationMapMarker>>(result.Markers).IsReadOnly);
        Assert.True(Assert.IsAssignableFrom<IList<StationCatalogueItem>>(result.WithoutCoordinates).IsReadOnly);
    }

    [Fact]
    public void Rejects_duplicate_identity_even_when_one_record_has_no_coordinates()
    {
        var located = Item(StationCatalogueSourceKind.Classic, "1", "محطة", 33m, 36m);
        var unlocated = Item(StationCatalogueSourceKind.Classic, "1", "محطة أخرى", null, null);
        Assert.Throws<ArgumentException>(() => StationMapProjection.Create([located, unlocated]));
    }

    [Theory]
    [InlineData("bad/id")]
    [InlineData(" station-1 ")]
    public void Rejects_malformed_source_record_ids(string sourceRecordId)
    {
        Assert.Throws<ArgumentException>(() => StationMapProjection.Create([
            Item(StationCatalogueSourceKind.Classic, sourceRecordId, "محطة", null, null)
        ]));
    }

    [Fact]
    public void Rejects_malformed_display_names()
    {
        Assert.Throws<ArgumentException>(() => StationMapProjection.Create([
            Item(StationCatalogueSourceKind.Classic, "1", "محطة\\nمكسورة", 33m, 36m)
        ]));
    }

    private static StationCatalogueItem Item(
        StationCatalogueSourceKind kind, string id, string name, decimal? latitude, decimal? longitude)
        => new(kind, id, name, null, null, latitude, longitude, null);
}
