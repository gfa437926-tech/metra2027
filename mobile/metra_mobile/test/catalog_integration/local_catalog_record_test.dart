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

  test('export envelope rejects malformed non-string keys without throwing', () {
    final malformed = <Object, Object?>{
      'kind': 'metra2027.local_catalog_export',
      7: 'unexpected-key',
    };
    expect(LocalCatalogExportEnvelope.tryParse(malformed), isNull);
  });

  test('tryParse rejects missing or malformed values instead of erasing them', () {
    final base = {
      'id': 'invalid-values',
      'stationId': 'st-a',
      'formType': 'rainfall',
      'createdAt': '2026-11-20T00:00:00.000Z',
      'updatedAt': '2026-11-21T00:00:00.000Z',
      'status': 'localSaved',
    };
    expect(LocalCatalogRecord.tryParse(base), isNull);
    expect(LocalCatalogRecord.tryParse({...base, 'values': 'not-a-map'}), isNull);
    expect(
      LocalCatalogRecord.tryParse({
        ...base,
        'values': <Object, Object?>{7: 'invalid-key'},
      }),
      isNull,
    );
  });

  test('tryParse rejects corrupt payload without throwing', () {
    expect(LocalCatalogRecord.tryParse({'id': 'x'}), isNull);
    expect(LocalCatalogRecord.tryParse(null), isNull);
  });
  test('tryParse rejects records from a newer unsupported schema', () {
    final futureRecord = {
      'schemaVersion': LocalCatalogRecord.currentSchemaVersion + 1,
      'id': 'future-1',
      'stationId': 'st-a',
      'formType': 'rainfall',
      'values': {'rainAmount': 8, 'futureField': 'preserve-me'},
      'createdAt': '2026-11-20T00:00:00.000Z',
      'updatedAt': '2026-11-21T00:00:00.000Z',
      'status': 'localSaved',
    };
    expect(LocalCatalogRecord.tryParse(futureRecord), isNull);
  });

  test('tryParse rejects malformed and nonpositive explicit schema versions', () {
    final base = {
      'id': 'bad-schema',
      'stationId': 'st-a',
      'formType': 'rainfall',
      'values': {'rainAmount': 8},
      'createdAt': '2026-11-20T00:00:00.000Z',
      'updatedAt': '2026-11-21T00:00:00.000Z',
      'status': 'localSaved',
    };
    expect(LocalCatalogRecord.tryParse({...base, 'schemaVersion': 'oops'}), isNull);
    expect(LocalCatalogRecord.tryParse({...base, 'schemaVersion': 0}), isNull);
    expect(LocalCatalogRecord.tryParse({...base, 'schemaVersion': -1}), isNull);
  });

  test('tryParse rejects unknown lifecycle states instead of relabeling them', () {
    final unknownStatus = {
      'schemaVersion': LocalCatalogRecord.currentSchemaVersion,
      'id': 'unknown-status',
      'stationId': 'st-a',
      'formType': 'rainfall',
      'values': {'rainAmount': 8},
      'createdAt': '2026-11-20T00:00:00.000Z',
      'updatedAt': '2026-11-21T00:00:00.000Z',
      'status': 'serverSynced',
    };
    expect(LocalCatalogRecord.tryParse(unknownStatus), isNull);
  });


  test('export envelope rejects future and malformed explicit schema versions', () {
    final base = {
      'kind': 'metra2027.local_catalog_export',
      'exportedAt': '2026-11-20T00:00:00.000Z',
      'recordCount': 0,
      'records': <Object>[],
    };
    expect(LocalCatalogExportEnvelope.tryParse({
      ...base,
      'schemaVersion': LocalCatalogRecord.currentSchemaVersion + 1,
    }), isNull);
    expect(LocalCatalogExportEnvelope.tryParse({
      ...base,
      'schemaVersion': 'oops',
    }), isNull);
    expect(LocalCatalogExportEnvelope.tryParse({
      ...base,
      'schemaVersion': 0,
    }), isNull);
  });

  test('export envelope rejects mismatched count but preserves partial rows', () {
    final base = {
      'kind': 'metra2027.local_catalog_export',
      'schemaVersion': LocalCatalogRecord.currentSchemaVersion,
      'exportedAt': '2026-11-20T00:00:00.000Z',
      'records': <Object>[{'broken': true}],
    };
    expect(LocalCatalogExportEnvelope.tryParse({...base, 'recordCount': 0}), isNull);
    final parsed = LocalCatalogExportEnvelope.tryParse({...base, 'recordCount': 1});
    expect(parsed, isNotNull);
    expect(parsed!.records, isEmpty);
  });
  test('tryParse rejects coerced non-string identity and metadata fields', () {
    final base = {
      'id': 'strict-types',
      'stationId': 'st-a',
      'formType': 'rainfall',
      'values': <String, Object?>{'rainAmount': 2},
      'createdAt': '2026-11-20T00:00:00.000Z',
      'updatedAt': '2026-11-21T00:00:00.000Z',
      'status': 'localSaved',
    };
    expect(LocalCatalogRecord.tryParse({...base, 'id': 42}), isNull);
    expect(LocalCatalogRecord.tryParse({...base, 'stationId': 42}), isNull);
    expect(LocalCatalogRecord.tryParse({...base, 'formType': 42}), isNull);
    expect(LocalCatalogRecord.tryParse({...base, 'createdAt': 42}), isNull);
    expect(LocalCatalogRecord.tryParse({...base, 'status': 42}), isNull);
    expect(LocalCatalogRecord.tryParse({...base, 'accountKey': 42}), isNull);
  });

  test('tryParse rejects value keys that collide after whitespace normalization', () {
    final malformed = {
      'id': 'duplicate-value-key',
      'stationId': 'st-a',
      'formType': 'rainfall',
      'values': <String, Object?>{
        'rainAmount': 2,
        ' rainAmount ': 9,
      },
      'createdAt': '2026-11-20T00:00:00.000Z',
      'updatedAt': '2026-11-21T00:00:00.000Z',
      'status': 'localSaved',
    };
    expect(LocalCatalogRecord.tryParse(malformed), isNull);
  });

}
