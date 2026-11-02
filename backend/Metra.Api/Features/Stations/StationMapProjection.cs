namespace Metra.Api.Features.Stations;

/// <summary>
/// Presentation-ready map marker. The key is source-qualified because a
/// classic and automatic source may legitimately reuse the same local ID.
/// </summary>
public sealed record StationMapMarker(
    string SourceQualifiedKey,
    StationCatalogueSourceKind SourceKind,
    string DisplayName,
    decimal Latitude,
    decimal Longitude);

public sealed record StationMapProjectionResult(
    IReadOnlyList<StationMapMarker> Markers,
    IReadOnlyList<StationCatalogueItem> WithoutCoordinates);

/// <summary>
/// Pure projection shared by API consumers' map adapters. It never fabricates
/// coordinates and never drops records: stations without a verified coordinate
/// pair are returned separately for the list/search experience.
/// </summary>
public static class StationMapProjection
{
    public static StationMapProjectionResult Create(
        IReadOnlyList<StationCatalogueItem> stations)
    {
        ArgumentNullException.ThrowIfNull(stations);

        var markers = new List<StationMapMarker>(stations.Count);
        var withoutCoordinates = new List<StationCatalogueItem>();
        var seenKeys = new HashSet<string>(StringComparer.Ordinal);

        foreach (var station in stations)
        {
            ArgumentNullException.ThrowIfNull(station);
            if (!Enum.IsDefined(station.SourceKind) ||
                string.IsNullOrWhiteSpace(station.SourceRecordId) ||
                string.IsNullOrWhiteSpace(station.DisplayName))
                throw new ArgumentException("Station projection input is malformed.", nameof(stations));

            if (station.Latitude is null && station.Longitude is null)
            {
                withoutCoordinates.Add(station);
                continue;
            }

            if (station.Latitude is not { } latitude ||
                station.Longitude is not { } longitude ||
                latitude is < -90m or > 90m ||
                longitude is < -180m or > 180m)
                throw new ArgumentException("Station coordinates must be a valid complete pair.", nameof(stations));

            var key = $"{station.SourceKind}:{station.SourceRecordId}";
            if (!seenKeys.Add(key))
                throw new ArgumentException("Station source identity must be unique.", nameof(stations));

            markers.Add(new(key, station.SourceKind, station.DisplayName, latitude, longitude));
        }

        return new(
            Array.AsReadOnly(markers.ToArray()),
            Array.AsReadOnly(withoutCoordinates.ToArray()));
    }
}
