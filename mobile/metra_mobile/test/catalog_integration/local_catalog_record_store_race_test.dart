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
    store.upsert(
      id: 'station-new::soil',
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
    expect(ids, containsAll(['station-old::rainfall', 'station-new::soil']));
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
}
