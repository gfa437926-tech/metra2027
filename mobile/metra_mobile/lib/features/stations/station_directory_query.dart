import '../../core/api/metra_api_client.dart';

/// Client-side match against a directory page already returned by the API.
/// Does not query the server and does not invent stations.
bool stationMatchesDirectoryQuery(StationDirectoryItem station, String rawQuery) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) return true;
  bool contains(String? value) =>
      value != null && value.toLowerCase().contains(query);
  return contains(station.nameArabic) ||
      contains(station.nameEnglish) ||
      contains(station.localCode) ||
      contains(station.wmoStationId);
}
