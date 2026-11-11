import 'package:flutter_test/flutter_test.dart';

/// Documents the forecasting station profile response shape from Backend.
/// Does not invent live meteorological values.
void main() {
  test('forecasting profile marks live values unavailable when null', () {
    final Map<String, dynamic> sample = <String, dynamic>{
      'source': 'metra_station_catalogue',
      'retrievedAtUtc': '2026-11-11T12:00:00Z',
      'latitude': 33.3,
      'longitude': 44.4,
      'elevationM': 34.0,
      'dataFreshness': 'catalogue_only',
      'meteorologicalValues': null,
      'noteAr': 'لا تُعرض قيم رصد على أنها لحظية قبل اعتماد عقد لقطة الرصد للتنبؤ.',
    };

    expect(sample['meteorologicalValues'], isNull);
    expect(sample['dataFreshness'], 'catalogue_only');
    expect(sample['source'], 'metra_station_catalogue');
    expect((sample['noteAr'] as String).isNotEmpty, isTrue);
  });
}
