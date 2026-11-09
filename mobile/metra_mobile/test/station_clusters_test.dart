import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/stations/station_clusters.dart';

StationDirectoryItem station({
  required String id,
  double? latitude = 33.5138,
  double? longitude = 36.2765,
}) => StationDirectoryItem(
  id: id,
  localCode: id,
  nameArabic: id,
  nameEnglish: id,
  stationType: 'classic',
  operationalStatus: 'active',
  approvalStatus: 'approved',
  isDemo: false,
  latitude: latitude,
  longitude: longitude,
);

void main() {
  test('groups stations sharing rounded coordinates without losing records', () {
    final clusters = clusterStationsByCoordinates([
      station(id: 'classic-1'),
      station(id: 'automatic-1', latitude: 33.5138001, longitude: 36.2765001),
      station(id: 'other', latitude: 34.0, longitude: 36.0),
    ]);

    expect(clusters, hasLength(2));
    expect(clusters.values.first.map((item) => item.id),
        containsAll(['classic-1', 'automatic-1']));
    expect(clusters.values.expand((items) => items), hasLength(3));
  });

  test('excludes invalid coordinates from clusters only', () {
    final located = station(id: 'located');
    final missing = station(id: 'missing', latitude: null, longitude: null);
    final invalid = station(id: 'invalid', latitude: 91, longitude: 181);

    final clusters = clusterStationsByCoordinates([located, missing, invalid]);
    expect(clusters.values.expand((items) => items).map((item) => item.id),
        ['located']);
  });

  test('returns immutable cluster map and member lists', () {
    final clusters = clusterStationsByCoordinates([station(id: 'one')]);
    expect(() => clusters.clear(), throwsUnsupportedError);
    expect(() => clusters.values.single.clear(), throwsUnsupportedError);
  });
}
