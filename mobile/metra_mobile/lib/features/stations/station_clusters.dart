import '../../core/api/metra_api_client.dart';

/// Groups stations that share the same rounded coordinates without dropping
/// station records. Stations with missing or invalid coordinates stay in the
/// directory list and are omitted only from map clusters.
Map<String, List<StationDirectoryItem>> clusterStationsByCoordinates(
  Iterable<StationDirectoryItem> stations,
) {
  final clusters = <String, List<StationDirectoryItem>>{};

  for (final station in stations) {
    if (!station.hasValidCoordinates) continue;
    final key =
        '${station.latitude!.toStringAsFixed(5)},${station.longitude!.toStringAsFixed(5)}';
    clusters.putIfAbsent(key, () => <StationDirectoryItem>[]).add(station);
  }

  return Map.unmodifiable({
    for (final entry in clusters.entries)
      entry.key: List<StationDirectoryItem>.unmodifiable(entry.value),
  });
}
