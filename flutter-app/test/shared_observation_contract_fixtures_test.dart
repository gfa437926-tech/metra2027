import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/observations/daily_observation_contract.dart';

/// Loads the same JSON fixtures used by .NET SharedObservationContractFixturesTests.
void main() {
  late Directory fixturesDir;

  setUpAll(() {
    fixturesDir = _locateFixtures();
  });

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
  // Prefer repo-root relative paths from package working directory (flutter-app).
  final ordered = <Directory>[
    Directory('test/fixtures/observation-v1/fixtures'),
    Directory('fixtures/observation-v1/fixtures'),
    Directory('contracts/observation-v1/fixtures'),
    Directory('../contracts/observation-v1/fixtures'),
    Directory('../../contracts/observation-v1/fixtures'),
  ];

  // Walk upward from Directory.current and from this test file location.
  var current = Directory.current.absolute;
  for (var i = 0; i < 8; i++) {
    ordered.add(Directory('${current.path}/contracts/observation-v1/fixtures'));
    current = current.parent;
  }

  final script = File.fromUri(Platform.script);
  if (script.existsSync()) {
    var dir = script.parent.absolute;
    for (var i = 0; i < 8; i++) {
      ordered.add(Directory('${dir.path}/contracts/observation-v1/fixtures'));
      dir = dir.parent;
    }
  }

  for (final dir in ordered) {
    final manifest = File('${dir.path}/manifest.json');
    if (dir.existsSync() && manifest.existsSync()) {
      return dir.absolute;
    }
  }

  fail(
    'Could not locate contracts/observation-v1/fixtures '
    '(cwd=${Directory.current.path})',
  );
}
