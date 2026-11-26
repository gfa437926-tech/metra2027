import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/catalog_integration/local_catalog_record.dart';

void main() {
  test('tryParse round-trip preserves core fields and schema', () {
    final original = LocalCatalogRecord(
      id: 'local-1',
      stationId: 'st-a',
      formType: 'rainfall',
      values: const {'observationDate': '2020-01-15', 'rainAmount': 3},
      createdAt: DateTime.utc(2020, 1, 15),
      updatedAt: DateTime.utc(2020, 1, 16),
      accountKey: 'user-1',
    );
    final parsed = LocalCatalogRecord.tryParse(original.toJson());
    expect(parsed, isNotNull);
    expect(parsed!.id, 'local-1');
    expect(parsed.stationId, 'st-a');
    expect(parsed.formType, 'rainfall');
    expect(parsed.values['rainAmount'], 3);
    expect(parsed.accountKey, 'user-1');
    expect(parsed.schemaVersion, LocalCatalogRecord.currentSchemaVersion);
  });

  test('filter isolates station and form type and excludes archived', () {
    final records = [
      LocalCatalogRecord(
        id: '1',
        stationId: 'st-a',
        formType: 'rainfall',
        values: const {'observationDate': '2020-01-01'},
        createdAt: DateTime.utc(2020, 1, 1),
        updatedAt: DateTime.utc(2020, 1, 2),
      ),
      LocalCatalogRecord(
        id: '2',
        stationId: 'st-b',
        formType: 'rainfall',
        values: const {'observationDate': '2020-01-03'},
        createdAt: DateTime.utc(2020, 1, 3),
        updatedAt: DateTime.utc(2020, 1, 4),
      ),
      LocalCatalogRecord(
        id: '3',
        stationId: 'st-a',
        formType: 'soil',
        values: const {'observationDate': '2020-01-05'},
        createdAt: DateTime.utc(2020, 1, 5),
        updatedAt: DateTime.utc(2020, 1, 6),
        status: LocalCatalogRecordStatus.localArchived,
      ),
    ];
    final filtered = LocalCatalogRecordQuery.filter(
      records: records,
      stationId: 'st-a',
      formType: 'rainfall',
    );
    expect(filtered.length, 1);
    expect(filtered.first.id, '1');
  });

  test('export envelope round-trip keeps records', () {
    final record = LocalCatalogRecord(
      id: 'e1',
      stationId: 'st-a',
      formType: 'agricultural',
      values: const {'x': 1},
      createdAt: DateTime.utc(2020, 1, 1),
      updatedAt: DateTime.utc(2020, 1, 2),
    );
    final envelope = LocalCatalogExportEnvelope(
      exportedAt: DateTime.utc(2020, 5, 1),
      records: [record],
    );
    final parsed = LocalCatalogExportEnvelope.tryParse(
      jsonDecode(jsonEncode(envelope.toJson())),
    );
    expect(parsed, isNotNull);
    expect(parsed!.records.single.id, 'e1');
  });

  test('tryParse rejects corrupt payload without throwing', () {
    expect(LocalCatalogRecord.tryParse({'id': 'x'}), isNull);
    expect(LocalCatalogRecord.tryParse(null), isNull);
  });
}
