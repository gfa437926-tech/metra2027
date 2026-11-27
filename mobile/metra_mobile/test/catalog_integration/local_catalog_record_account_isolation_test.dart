import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/catalog_integration/local_catalog_record.dart';
import 'package:metra_mobile/core/catalog_integration/local_catalog_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('account B cannot read, mutate, or overwrite account A records', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalCatalogRecordStore.forTesting();
    await store.ensureLoaded();

    store.setActiveAccountKey('account-a');
    store.upsert(
      id: 'shared-id',
      stationId: 'station-1',
      formType: 'rainfall',
      values: const {'amount': 12},
    );
    await store.flushForTesting();

    store.setActiveAccountKey('account-b');
    expect(store.count, 0);
    expect(store.getById('shared-id'), isNull);
    expect(store.list(), isEmpty);
    expect(store.archive('shared-id'), isFalse);
    expect(store.restore('shared-id'), isFalse);
    expect(store.delete('shared-id'), isFalse);
    expect(
      () => store.upsert(
        id: 'shared-id',
        stationId: 'station-1',
        formType: 'rainfall',
        values: const {'amount': 99},
      ),
      throwsStateError,
    );

    store.setActiveAccountKey('account-a');
    expect(store.count, 1);
    expect(store.getById('shared-id')?.values['amount'], 12);
    expect(store.list().single.id, 'shared-id');
  });

  test('signed-out scope exposes only unassigned records', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalCatalogRecordStore.forTesting();
    await store.ensureLoaded();

    store.setActiveAccountKey('account-a');
    store.upsert(
      id: 'private-record',
      stationId: 'station-1',
      formType: 'soil',
      values: const {'depth': 30},
    );
    await store.flushForTesting();

    store.setActiveAccountKey(null);
    expect(store.count, 0);
    expect(store.getById('private-record'), isNull);
    expect(store.list(), isEmpty);
    expect(store.listUnassigned(), isEmpty);
  });
  test('account changes notify catalogue listeners exactly when scope changes', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalCatalogRecordStore.forTesting();
    await store.ensureLoaded();
    var notifications = 0;
    void listener() => notifications++;
    store.addListener(listener);

    store.setActiveAccountKey('account-a');
    expect(notifications, 1);
    store.setActiveAccountKey('account-a');
    expect(notifications, 1);
    store.setActiveAccountKey('account-b');
    expect(notifications, 2);

    store.removeListener(listener);
  });

  test('legacy record can only be claimed by the matching active account', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalCatalogRecordStore.forTesting();
    await store.ensureLoaded();

    final legacy = store.upsert(
      stationId: 'station-legacy',
      formType: 'rainfall',
      values: const {'amount': 5},
    );
    await store.flushForTesting();

    expect(store.claimToAccount(legacy.id, 'account-a'), isNull);
    store.setActiveAccountKey('account-a');
    expect(store.claimToAccount(legacy.id, 'account-b'), isNull);
    final claimed = store.claimToAccount(legacy.id, 'account-a');
    expect(claimed?.accountKey, 'account-a');
    expect(claimed?.values['amount'], 5);
  });

  test('imports cannot add or overwrite records owned by another account', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalCatalogRecordStore.forTesting();
    await store.ensureLoaded();

    store.setActiveAccountKey('account-a');
    store.upsert(
      id: 'owned-by-a',
      stationId: 'station-a',
      formType: 'rainfall',
      values: const {'amount': 11},
    );
    await store.flushForTesting();

    final foreign = LocalCatalogRecord(
      id: 'owned-by-a',
      stationId: 'station-a',
      formType: 'rainfall',
      values: const {'amount': 999},
      createdAt: DateTime.utc(2026, 11, 20),
      updatedAt: DateTime.utc(2026, 11, 27),
      accountKey: 'account-a',
    );
    final foreignNew = LocalCatalogRecord(
      id: 'foreign-new',
      stationId: 'station-b',
      formType: 'soil',
      values: const {'depth': 30},
      createdAt: DateTime.utc(2026, 11, 20),
      updatedAt: DateTime.utc(2026, 11, 27),
      accountKey: 'account-a',
    );

    store.setActiveAccountKey('account-b');
    final result = store.importJson(
      jsonEncode([foreign.toJson(), foreignNew.toJson()]),
      overwriteExisting: true,
    );
    expect(result['added'], 0);
    expect(result['updated'], 0);
    expect(result['skipped'], 2);
    expect(store.list(), isEmpty);

    store.setActiveAccountKey('account-a');
    expect(store.getById('owned-by-a')?.values['amount'], 11);
    expect(store.getById('foreign-new'), isNull);
  });

}
