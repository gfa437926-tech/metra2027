import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/observations/daily_observation_contract.dart';

/// Loads the same JSON fixtures used by .NET SharedObservationContractFixturesTests.
void main() {
  final fixturesDir = _locateFixtures();

  test('shared observation fixtures directory is present', () {
    expect(File('${fixturesDir.path}/manifest.json').existsSync(), isTrue);
  });

  test('daily fixtures agree with DailyObservationContract', () {
    final manifest = jsonDecode(
      File('${fixturesDir.path}/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final files = (manifest['fixtures'] as List).cast<String>();

    for (final name in files) {
      final data = jsonDecode(File('${fixturesDir.path}/$name').readAsStringSync())
          as Map<String, dynamic>;
      if (data['observationType'] != 'daily') continue;

      final reportType = data['reportType'] as String;
      final values = (data['values'] as Map).map(
        (k, v) => MapEntry(k as String, (v as String?) ?? ''),
      );
      final agreement = data['responsibilityAgreement'] as bool? ?? false;
      final expectValid = data['expectValid'] as bool;
      final expectedFields =
          ((data['expectErrorFields'] as List?) ?? const []).cast<String>().toSet();

      final errors = DailyObservationContract.validate(
        reportType,
        values,
        responsibilityAgreement: agreement,
      );

      if (expectValid) {
        expect(errors, isEmpty, reason: 'Fixture ${data['id']} should be valid, got $errors');
      } else {
        expect(errors, isNotEmpty, reason: 'Fixture ${data['id']} should fail');
        for (final field in expectedFields) {
          expect(errors.containsKey(field), isTrue,
              reason: 'Fixture ${data['id']} missing error field $field in $errors');
        }
      }
    }
  });
}

Directory _locateFixtures() {
  // flutter-app/test -> repo root contracts/
  final candidates = [
    Directory('../../contracts/observation-v1/fixtures'),
    Directory('../contracts/observation-v1/fixtures'),
    Directory('contracts/observation-v1/fixtures'),
  ];
  for (final dir in candidates) {
    if (dir.existsSync() && File('${dir.path}/manifest.json').existsSync()) {
      return dir.absolute;
    }
  }
  // Walk up from current
  var current = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate =
        Directory('${current.path}/contracts/observation-v1/fixtures');
    if (candidate.existsSync()) return candidate;
    current = current.parent;
  }
  fail('Could not locate contracts/observation-v1/fixtures');
}
