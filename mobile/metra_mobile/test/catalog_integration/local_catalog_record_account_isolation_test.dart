import 'package:flutter_test/flutter_test.dart';
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
}
