import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/stations/station_selection.dart';

StationDirectoryItem _item({
  required String id,
  String code = 'ORBM',
  String ar = 'بغداد',
}) {
  return StationDirectoryItem(
    id: id,
    localCode: code,
    nameArabic: ar,
    nameEnglish: 'X',
    stationType: 'classic',
    operationalStatus: 'active',
    approvalStatus: 'approved',
    isDemo: false,
  );
}

void main() {
  test('formatSelectedStationLabel includes name and code', () {
    expect(formatSelectedStationLabel(_item(id: '1')), 'بغداد (ORBM)');
  });

  test('formatSelectedStationLabel falls back to id when empty', () {
    expect(formatSelectedStationLabel(_item(id: 'uuid-1', code: '', ar: '')), 'uuid-1');
  });
}
