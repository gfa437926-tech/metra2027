import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/catalog_integration/local_catalog_record.dart';
import 'package:metra_mobile/core/catalog_integration/local_catalog_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('write before initial disk load preserves existing catalogue records', () async {
    final oldRecord = LocalCatalogRecord(
      id: 'station-old::rainfall',
      stationId: 'station-old',
      formType: 'rainfall',
      values: const {'amount': 12},
      createdAt: DateTime.utc(2026, 11, 20),
      updatedAt: DateTime.utc(2026, 11, 20),
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.local_catalog_records.v1': jsonEncode([oldRecord.toJson()]),
    });

    final store = LocalCatalogRecordStore.forTesting();
    final loading = store.ensureLoaded();
    final added = store.upsert(
      stationId: 'station-new',
      formType: 'soil',
      values: const {'depth': 30},
    );

    await loading;
    await store.flushForTesting();

    final prefs = await SharedPreferences.getInstance();
    final rows = jsonDecode(
      prefs.getString('metra2027.local_catalog_records.v1')!,
    ) as List;
    final ids = rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['id'])
        .toSet();
    expect(ids, containsAll(['station-old::rainfall', added.id]));
  });

  test('legacy single-record payload does not replace a newer imported record', () async {
    final diskRecord = LocalCatalogRecord(
      id: 'legacy-single-record',
      stationId: 'station-1',
      formType: 'rainfall',
      values: const {'amount': 3},
      createdAt: DateTime.utc(2026, 11, 20),
      updatedAt: DateTime.utc(2026, 11, 20),
    );
    final importedRecord = LocalCatalogRecord(
      id: 'legacy-single-record',
      stationId: 'station-1',
      formType: 'rainfall',
      values: const {'amount': 15},
      createdAt: DateTime.utc(2026, 11, 20),
      updatedAt: DateTime.utc(2026, 11, 27),
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.local_catalog_records.v1': jsonEncode(diskRecord.toJson()),
    });
    final store = LocalCatalogRecordStore.forTesting();

    final result = store.importJson(jsonEncode([importedRecord.toJson()]));
    expect(result['added'], 1);

    await store.ensureLoaded();
    await store.flushForTesting();

    expect(store.getById(importedRecord.id)?.values['amount'], 15);
  });

  test('concurrent initial-load callers await the same completed load', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalCatalogRecordStore.forTesting();

    final first = store.ensureLoaded();
    final second = store.ensureLoaded();
    final reports = await Future.wait([first, second]);

    expect(reports, hasLength(2));
    expect(reports.every((report) => report.loaded == 0), isTrue);
    expect(store.isLoaded, isTrue);
  });

  test('clear before first read clears the disk payload instead of restoring it', () async {
    final oldRecord = LocalCatalogRecord(
      id: 'old-record',
      stationId: 'station-old',
      formType: 'rainfall',
      values: const {'amount': 4},
      createdAt: DateTime.utc(2026, 11, 20),
      updatedAt: DateTime.utc(2026, 11, 20),
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.local_catalog_records.v1': jsonEncode([oldRecord.toJson()]),
    });
    final store = LocalCatalogRecordStore.forTesting();

    await store.clearAll(persist: true);

    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(prefs.getString('metra2027.local_catalog_records.v1')!),
      isEmpty,
    );
    expect(store.count, 0);
  });
  test('explicit id updates fail closed before initial load completes', () async {
    final oldRecord = LocalCatalogRecord(
      id: 'stable-existing-id',
      stationId: 'station-old',
      formType: 'rainfall',
      values: const {'amount': 7},
      createdAt: DateTime.utc(2026, 11, 20),
      updatedAt: DateTime.utc(2026, 11, 20),
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.local_catalog_records.v1': jsonEncode([oldRecord.toJson()]),
    });
    final store = LocalCatalogRecordStore.forTesting();

    expect(
      () => store.upsert(
        id: 'stable-existing-id',
        stationId: 'station-old',
        formType: 'rainfall',
        values: const {'amount': 99},
      ),
      throwsStateError,
    );

    await store.ensureLoaded();
    expect(store.getById('stable-existing-id')?.values['amount'], 7);
  });

}
