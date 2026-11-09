import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/observations/hourly_observation_contract.dart';

void main() {
  test('all shared hourly fixtures execute against the Flutter validator', () {
    final manifestFile = _locateSharedManifest();
    final directory = manifestFile.parent;
    final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['contractVersion'], '1.0');
    final names = (manifest['fixtures'] as List<dynamic>).cast<String>();
    final fixtures = names
        .map((name) => jsonDecode(File('${directory.path}/$name').readAsStringSync())
            as Map<String, dynamic>)
        .where((fixture) => fixture['observationType'] == 'hourly')
        .toList();
    expect(fixtures, hasLength(2));

    for (final fixture in fixtures) {
      final id = fixture['id'] as String;
      final raw = fixture['values'] as Map<String, dynamic>;
      final values = raw.map((key, value) => MapEntry(key, value?.toString() ?? ''));
      final errors = HourlyObservationContract.validate(values);
      if (fixture['expectValid'] == true) {
        expect(errors, isEmpty, reason: '$id: $errors');
      } else {
        expect(errors, isNotEmpty, reason: '$id should be rejected');
        for (final field in (fixture['expectErrorFields'] as List<dynamic>).cast<String>()) {
          expect(errors.containsKey(field), isTrue, reason: '$id expected $field: $errors');
        }
      }
    }
  });

  test('conditional hourly fields follow UTC synoptic and precipitation hours', () {
    final base = _validValues('00')
      ..remove('precipitationAmount')
      ..remove('pressureSlope')
      ..remove('pressureShape')
      ..remove('pastWeather');
    final errors = HourlyObservationContract.validate(base);
    expect(errors.keys, containsAll(['precipitationAmount', 'pressureSlope', 'pressureShape', 'pastWeather']));
    expect(HourlyObservationContract.validate(_validValues('01')), isEmpty);
  });

  test('all 24 UTC hours enforce the exact conditional field matrix', () {
    const synopticHours = {0, 3, 6, 9, 12, 15, 18, 21};
    const precipitationHours = {0, 6, 12, 18};
    for (var hour = 0; hour < 24; hour++) {
      final text = hour.toString().padLeft(2, '0');
      final valid = _validValues(text);
      expect(HourlyObservationContract.validate(valid), isEmpty, reason: '$text UTC should be valid');

      final expected = <String>{
        if (synopticHours.contains(hour)) ...{'pressureSlope', 'pressureShape', 'pastWeather'},
        if (precipitationHours.contains(hour)) 'precipitationAmount',
      };
      for (final field in expected) {
        final missing = Map<String, String>.from(valid)..remove(field);
        expect(
          HourlyObservationContract.validate(missing).containsKey(field),
          isTrue,
          reason: '$field must be required at $text UTC',
        );
      }
      final optional = <String>{
        if (!synopticHours.contains(hour)) ...{'pressureSlope', 'pressureShape', 'pastWeather'},
        if (!precipitationHours.contains(hour)) 'precipitationAmount',
      };
      for (final field in optional) {
        final missing = Map<String, String>.from(valid)..remove(field);
        expect(
          HourlyObservationContract.validate(missing).containsKey(field),
          isFalse,
          reason: '$field must remain optional at $text UTC',
        );
      }
    }
  });

  test('dry temperature cannot be lower than wet temperature', () {
    final values = _validValues('01');
    values['dryTemp'] = '+10.0';
    values['wetTemp'] = '+15.0';
    expect(HourlyObservationContract.validate(values).containsKey('dryTemp'), isTrue);
  });

  test('invalid UTC hour and out-of-range codes are rejected', () {
    expect(HourlyObservationContract.validate(_validValues('24')).containsKey('utcTime'), isTrue);
    final values = _validValues('01')..['visibility'] = '201';
    expect(HourlyObservationContract.validate(values).containsKey('visibility'), isTrue);
  });
}

Map<String, String> _validValues(String hour) => {
  'utcTime': hour,
  'dryTemp': '+25.0',
  'wetTemp': '+18.0',
  'dewPoint': '+12.0',
  'stationPressure': '1013.2',
  'seaLevelPressure': '1015.0',
  'relativeHumidity': '045',
  'windDirection': '18',
  'windSpeed': '05',
  'visibility': '010',
  'totalCloudCover': '4',
  'cover12': '3',
  'cover123': '4',
  if ({0, 6, 12, 18}.contains(int.tryParse(hour))) 'precipitationAmount': '000.0',
  if ({0, 3, 6, 9, 12, 15, 18, 21}.contains(int.tryParse(hour))) ...{
    'pressureSlope': '1.2',
    'pressureShape': '3',
    'pastWeather': '0',
  },
};

File _locateSharedManifest() {
  final candidates = [
    File('../contracts/observation-v1/fixtures/manifest.json'),
    File('contracts/observation-v1/fixtures/manifest.json'),
    File('../../contracts/observation-v1/fixtures/manifest.json'),
  ];
  for (final candidate in candidates) {
    if (candidate.existsSync()) return candidate;
  }
  throw const FileSystemException('Shared observation fixture manifest not found');
}
