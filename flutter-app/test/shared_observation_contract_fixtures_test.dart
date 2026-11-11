import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/observations/daily_observation_contract.dart';

/// Executes the canonical repository JSON fixtures against the Flutter validator.
void main() {
  test('all shared daily fixtures match DailyObservationContract expectations', () {
    final manifestFile = _locateSharedManifest();
    final fixturesDirectory = manifestFile.parent;
    final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['contractVersion'], '1.0');

    final fixtureNames = (manifest['fixtures'] as List<dynamic>).cast<String>();
    final dailyFixtures = fixtureNames
        .map((name) => jsonDecode(File('${fixturesDirectory.path}/$name').readAsStringSync())
            as Map<String, dynamic>)
        .where((fixture) => fixture['observationType'] == 'daily')
        .toList();

    expect(dailyFixtures, hasLength(6));
    for (final fixture in dailyFixtures) {
      final id = fixture['id'] as String;
      final valuesJson = fixture['values'] as Map<String, dynamic>;
      final values = valuesJson.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
      final errors = DailyObservationContract.validate(
        fixture['reportType'] as String,
        values,
        responsibilityAgreement: fixture['responsibilityAgreement'] == true,
      );
      final expectedValid = fixture['expectValid'] as bool;
      final expectedErrorFields = (fixture['expectErrorFields'] as List<dynamic>)
          .cast<String>();

      if (expectedValid) {
        expect(errors, isEmpty, reason: '$id: $errors');
      } else {
        expect(errors, isNotEmpty, reason: '$id should be rejected');
        for (final field in expectedErrorFields) {
          expect(errors.containsKey(field), isTrue,
              reason: '$id should report $field; actual: $errors');
        }
      }
    }
  });

  test('daily 24h valid values pass the client contract', () {
    final errors = DailyObservationContract.validate(
      '24h',
      {
        'minTemp': '12.5',
        'maxTemp': '28.0',
        'precipitation': '012.5',
        'snowThickness': '000',
        'evaporation': '03.2',
        'sunshineDuration': '08.5',
        'sunshinePercentage': '070',
        'maxGustSpeed': '12',
        'maxGustDirection': '18',
        'maxGustTime': '14.5',
        'maxHumidity': '085',
        'maxHumidityTime': '06.0',
        'minHumidity': '35',
        'minHumidityTime': '15.0',
      },
      responsibilityAgreement: true,
    );
    expect(errors, isEmpty, reason: '$errors');
  });

  test('daily 06utc valid values pass the client contract', () {
    final errors = DailyObservationContract.validate(
      '06utc',
      {
        'minTemp': '08.0',
        'maxTemp': '19.5',
        'precipitation': '000.0',
        'snowThickness': '000',
      },
      responsibilityAgreement: true,
    );
    expect(errors, isEmpty, reason: '$errors');
  });

  test('daily max below min is rejected on maxTemp', () {
    final errors = DailyObservationContract.validate(
      '06utc',
      {
        'minTemp': '20.0',
        'maxTemp': '10.0',
        'precipitation': '000.0',
        'snowThickness': '000',
      },
      responsibilityAgreement: true,
    );
    expect(errors.containsKey('maxTemp'), isTrue, reason: '$errors');
  });

  test('daily submission requires responsibility agreement', () {
    final errors = DailyObservationContract.validate(
      '06utc',
      {
        'minTemp': '08.0',
        'maxTemp': '19.5',
        'precipitation': '000.0',
        'snowThickness': '000',
      },
      responsibilityAgreement: false,
    );
    expect(errors.containsKey('responsibilityAgreement'), isTrue);
  });

  test('daily missing markers with # are accepted for required fields', () {
    final errors = DailyObservationContract.validate(
      '06utc',
      {
        'minTemp': '#',
        'maxTemp': '#',
        'precipitation': '#',
        'snowThickness': '#',
      },
      responsibilityAgreement: true,
    );
    expect(errors, isEmpty, reason: '$errors');
  });
}

File _locateSharedManifest() {
  final candidates = <File>[
    File('../contracts/observation-v1/fixtures/manifest.json'),
    File('contracts/observation-v1/fixtures/manifest.json'),
    File('../../contracts/observation-v1/fixtures/manifest.json'),
  ];
  for (final candidate in candidates) {
    if (candidate.existsSync()) return candidate;
  }
  throw const FileSystemException(
    'Could not locate contracts/observation-v1/fixtures/manifest.json',
  );
}
