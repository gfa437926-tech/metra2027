import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/forecast_centres/forecast_catalogue_distance.dart';
import 'package:metra_mobile/features/stations/station_directory_query.dart';
import 'package:metra_mobile/features/workspaces/workspace_period.dart';

StationDirectoryItem _station({
  String nameArabic = 'محطة',
  String nameEnglish = 'Station',
  String localCode = 'ST-1',
  String? wmo,
}) =>
    StationDirectoryItem(
      id: '11111111-1111-4111-8111-111111111111',
      localCode: localCode,
      nameArabic: nameArabic,
      nameEnglish: nameEnglish,
      stationType: 'classic',
      operationalStatus: 'active',
      approvalStatus: 'approved',
      isDemo: false,
      wmoStationId: wmo,
    );

void main() {
  test('directory query matches code, names, and WMO id without calling the API', () {
    final station = _station(
      nameArabic: 'محطة الساحل',
      nameEnglish: 'Coastal Station',
      localCode: 'CL-09',
      wmo: '40430',
    );
    expect(stationMatchesDirectoryQuery(station, '  '), isTrue);
    expect(stationMatchesDirectoryQuery(station, 'cl-09'), isTrue);
    expect(stationMatchesDirectoryQuery(station, 'ساحل'), isTrue);
    expect(stationMatchesDirectoryQuery(station, 'COASTAL'), isTrue);
    expect(stationMatchesDirectoryQuery(station, '40430'), isTrue);
    expect(stationMatchesDirectoryQuery(station, '11111111-1111'), isTrue);
    expect(stationMatchesDirectoryQuery(station, 'classic'), isTrue);
    expect(stationMatchesDirectoryQuery(station, 'غير موجود'), isFalse);
  });

  test('workspace period rejects an end day before the start day', () {
    expect(workspacePeriodError(null, DateTime(2026, 1, 2)), isNull);
    expect(
      workspacePeriodError(DateTime(2026, 1, 2, 23), DateTime(2026, 1, 2, 1)),
      isNull,
    );
    expect(
      workspacePeriodError(DateTime(2026, 3, 10), DateTime(2026, 3, 9, 18)),
      isNotNull,
    );
  });

  test('catalogue distance is null for missing coordinates and finite for one degree', () {
    expect(
      forecastCatalogueDistanceKm(
        latitudeA: null,
        longitudeA: 0,
        latitudeB: 0,
        longitudeB: 1,
      ),
      isNull,
    );
    expect(
      forecastCatalogueDistanceKm(
        latitudeA: 91,
        longitudeA: 0,
        latitudeB: 0,
        longitudeB: 0,
      ),
      isNull,
    );
    final km = forecastCatalogueDistanceKm(
      latitudeA: 0,
      longitudeA: 0,
      latitudeB: 0,
      longitudeB: 1,
    );
    expect(km, isNotNull);
    expect(km!, inInclusiveRange(111.0, 111.4));
  });

  test('sortStationDirectoryLocally orders by Arabic name then code', () {
    final rows = [
      _station(nameArabic: 'ب', localCode: 'B1'),
      _station(nameArabic: 'أ', localCode: 'A1'),
      _station(nameArabic: 'أ', localCode: 'A0'),
    ];
    // Give distinct ids via copy — _station uses fixed id; mutate via localCode only.
    final sorted = sortStationDirectoryLocally(rows);
    expect(sorted.map((s) => s.localCode).toList(), ['A0', 'A1', 'B1']);
  });

  test('filterAndSortStationDirectory applies query and mineOnly', () {
    final rows = [
      _station(nameArabic: 'محطة الساحل', localCode: 'CL-09'),
      _station(nameArabic: 'محطة داخلية', localCode: 'IN-01'),
    ];
    final mine = filterAndSortStationDirectory(
      rows: rows,
      query: 'ساحل',
      mineOnly: true,
      hasOperationalAccess: (id) => true,
    );
    expect(mine.length, 1);
    expect(mine.first.localCode, 'CL-09');
  });
}
