import '../../core/api/metra_api_client.dart';

/// Client-side match against a directory page already returned by the API.
/// Does not query the server and does not invent stations.
bool stationMatchesDirectoryQuery(
  StationDirectoryItem station,
  String rawQuery,
) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) return true;
  bool contains(String? value) =>
      value != null && value.toLowerCase().contains(query);
  return contains(station.nameArabic) ||
      contains(station.nameEnglish) ||
      contains(station.localCode) ||
      contains(station.wmoStationId) ||
      contains(station.id) ||
      contains(station.stationType);
}

/// Stable local ordering for directory rows already returned by the API.
/// Prefers Arabic name, then English, then local code, then id.
List<StationDirectoryItem> sortStationDirectoryLocally(
  Iterable<StationDirectoryItem> rows,
) {
  final list = List<StationDirectoryItem>.of(rows);
  int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  list.sort((a, b) {
    final byAr = cmp(a.nameArabic, b.nameArabic);
    if (byAr != 0) return byAr;
    final byEn = cmp(a.nameEnglish, b.nameEnglish);
    if (byEn != 0) return byEn;
    final byCode = cmp(a.localCode, b.localCode);
    if (byCode != 0) return byCode;
    return a.id.compareTo(b.id);
  });
  return list;
}

/// Applies local query + optional operational-access predicate, then sorts.
List<StationDirectoryItem> filterAndSortStationDirectory({
  required Iterable<StationDirectoryItem> rows,
  required String query,
  bool mineOnly = false,
  bool Function(String stationId)? hasOperationalAccess,
}) {
  final filtered = rows.where((station) {
    if (mineOnly) {
      final access = hasOperationalAccess;
      if (access == null || !access(station.id)) return false;
    }
    return stationMatchesDirectoryQuery(station, query);
  });
  return sortStationDirectoryLocally(filtered);
}
