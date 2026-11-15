import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/stations/greenfield_station_directory_item.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  Map<String, dynamic> station({
    String id = stationId,
    String code = 'MET-001',
    String approval = 'approved',
    String operation = 'active',
    Object? latitude = 35.5,
    Object? longitude = 36.3,
  }) => {
    'id': id,
    'station_code': code,
    'name_ar': 'محطة اختبار',
    'name_en': 'Test station',
    'wmo_identifier': '40001',
    'station_type_code': 'synoptic',
    'station_type_name_ar': 'سينوبتيكية',
    'station_type_name_en': 'Synoptic',
    'approval_status': approval,
    'operational_status': operation,
    'latitude': latitude,
    'longitude': longitude,
    'elevation_m': 512.5,
    'timezone_name': 'Asia/Damascus',
    'location_source': 'survey',
    'horizontal_accuracy_m': 4.0,
  };

  test('parses the normalized flat projection without legacy fields', () {
    final item = GreenfieldStationDirectoryItem.fromJson(station());
    expect(item.id, stationId);
    expect(item.stationCode, 'MET-001');
    expect(item.stationTypeNameArabic, 'سينوبتيكية');
    expect(item.latitude, 35.5);
    expect(item.longitude, 36.3);
    expect(item.timezoneName, 'Asia/Damascus');
    expect(item.locationSource, 'survey');
    expect(item.horizontalAccuracyM, 4);
  });

  test('permits a station with no current location', () {
    final item = GreenfieldStationDirectoryItem.fromJson(
      station(latitude: null, longitude: null),
    );
    expect(item.hasCoordinates, isFalse);
  });

  test('rejects half coordinates and out-of-range coordinates', () {
    expect(
      () => GreenfieldStationDirectoryItem.fromJson(
        station(latitude: 35.5, longitude: null),
      ),
      throwsFormatException,
    );
    expect(
      () => GreenfieldStationDirectoryItem.fromJson(
        station(latitude: 91, longitude: 36.3),
      ),
      throwsFormatException,
    );
    expect(
      () => GreenfieldStationDirectoryItem.fromJson(
        station(latitude: 35.5, longitude: -181),
      ),
      throwsFormatException,
    );
  });

  test('rejects stations outside the approved directory lifecycle', () {
    expect(
      () => GreenfieldStationDirectoryItem.fromJson(
        station(approval: 'pending'),
      ),
      throwsFormatException,
    );
    expect(
      () => GreenfieldStationDirectoryItem.fromJson(
        station(operation: 'inactive'),
      ),
      throwsFormatException,
    );
    expect(
      GreenfieldStationDirectoryItem.fromJson(
        station(operation: 'temporarily_closed'),
      ).operationalStatus,
      'temporarily_closed',
    );
  });

  test('rejects malformed ids, negative accuracy and numeric strings', () {
    expect(
      () => GreenfieldStationDirectoryItem.fromJson(station(id: 'legacy-id')),
      throwsFormatException,
    );
    expect(
      () => GreenfieldStationDirectoryItem.fromJson(
        station()..['horizontal_accuracy_m'] = -0.1,
      ),
      throwsFormatException,
    );
    expect(
      () => GreenfieldStationDirectoryItem.fromJson(
        station()..['elevation_m'] = '512.5',
      ),
      throwsFormatException,
    );
  });

  test('rejects legacy and unknown fields instead of silently accepting another schema', () {
    expect(
      () => GreenfieldStationDirectoryItem.fromJson(
        station()..['local_station_code'] = 'OLD-001',
      ),
      throwsFormatException,
    );
    expect(
      () => GreenfieldStationDirectoryItem.fromJson(
        station()..['is_demo'] = false,
      ),
      throwsFormatException,
    );
  });

  test('rejects duplicate station ids or codes in the complete response', () {
    expect(
      () => GreenfieldStationDirectoryItem.parseList([
        station(),
        station(code: 'met-001'),
      ]),
      throwsFormatException,
    );
    expect(
      () => GreenfieldStationDirectoryItem.parseList([
        station(),
        station(id: '22222222-2222-4222-8222-222222222222'),
      ]),
      throwsFormatException,
    );
  });

  test('bounds the response and never returns a partial catalogue', () {
    expect(
      GreenfieldStationDirectoryItem.parseList([station()]),
      hasLength(1),
    );
    expect(
      () => GreenfieldStationDirectoryItem.parseList(List.filled(501, station())),
      throwsFormatException,
    );
    expect(
      () => GreenfieldStationDirectoryItem.parseList([station(), null]),
      throwsFormatException,
    );
  });
}
