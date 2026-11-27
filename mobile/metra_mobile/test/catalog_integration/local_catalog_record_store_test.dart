import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metra_mobile/core/catalog_integration/local_catalog_record.dart';
import 'package:metra_mobile/core/catalog_integration/local_catalog_record_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('malformed disk JSON is counted as corrupt exactly once', () async {
    SharedPreferences.setMockInitialValues({
      'metra2027.local_catalog_records.v1': '{malformed',
    });
    final store = LocalCatalogRecordStore.forTesting();

    final report = await store.ensureLoaded();

    expect(report.loaded, 0);
    expect(report.skippedCorrupt, 1);
    expect(store.lastSkippedCorrupt, 1);
  });

  test('JSON null disk payload is counted as corrupt and not trusted', () async {
    SharedPreferences.setMockInitialValues({
      'metra2027.local_catalog_records.v1': 'null',
    });
    final store = LocalCatalogRecordStore.forTesting();

    final report = await store.ensureLoaded();

    expect(report.loaded, 0);
    expect(report.skippedCorrupt, 1);
    expect(store.lastSkippedCorrupt, 1);
  });

  test('partial import reports malformed rows alongside valid records', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalCatalogRecordStore.instance;
    await store.ensureLoaded();

    final valid = LocalCatalogRecord(
      id: 'valid-1',
      stationId: 'station-1',
      formType: 'rainfall',
      values: const {'observationDate': '2026-11-27'},
      createdAt: DateTime.utc(2026, 11, 27),
      updatedAt: DateTime.utc(2026, 11, 27),
    );

    final result = store.importJson(
      jsonEncode([valid.toJson(), {'id': 'malformed'}]),
    );

    expect(result['added'], 1);
    expect(result['corrupt'], 1);
    expect(store.getById('valid-1'), isNotNull);
  });
  test('envelope import reports malformed rows alongside valid records', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalCatalogRecordStore.forTesting();
    await store.ensureLoaded();

    final valid = LocalCatalogRecord(
      id: 'envelope-valid',
      stationId: 'station-1',
      formType: 'soil',
      values: const {'depth': 20},
      createdAt: DateTime.utc(2026, 11, 27),
      updatedAt: DateTime.utc(2026, 11, 27),
    );
    final envelope = LocalCatalogExportEnvelope(
      exportedAt: DateTime.utc(2026, 11, 27),
      records: [valid],
    ).toJson();
    envelope['records'] = [valid.toJson(), {'id': 'malformed'}];
    envelope['recordCount'] = 2;

    final result = store.importJson(jsonEncode(envelope));

    expect(result['added'], 1);
    expect(result['corrupt'], 1);
    expect(store.getById('envelope-valid'), isNotNull);
  });

  test('malformed non-string record keys are rejected without throwing', () {
    final malformed = <Object, Object?>{7: 'unexpected-key'};
    expect(LocalCatalogRecord.tryParse(malformed), isNull);
  });

}
