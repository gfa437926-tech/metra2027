import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/stations/station_directory_screen.dart';

StationDirectoryItem _item({
  required String id,
  required String code,
  required String ar,
  String en = 'Station',
  String? wmo,
}) {
  return StationDirectoryItem(
    id: id,
    localCode: code,
    nameArabic: ar,
    nameEnglish: en,
    stationType: 'classic',
    operationalStatus: 'active',
    approvalStatus: 'approved',
    isDemo: false,
    wmoStationId: wmo,
  );
}

void main() {
  test('filterStationDirectory matches code and arabic name', () {
    final rows = [
      _item(id: '1', code: 'ORBM', ar: 'بغداد', wmo: '40650'),
      _item(id: '2', code: 'ORBI', ar: 'البصرة'),
    ];
    expect(filterStationDirectory(rows, query: 'بغد').single.localCode, 'ORBM');
    expect(filterStationDirectory(rows, query: 'orbi').single.id, '2');
    expect(filterStationDirectory(rows, query: '40650').single.id, '1');
    expect(filterStationDirectory(rows, query: 'xyz'), isEmpty);
    expect(filterStationDirectory(rows, query: '  ').length, 2);
  });
}
