import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/drafts/observation_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('draft queries and cleanup remain isolated across accounts', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ObservationDraftStore.instance;
    await store.ensureLoaded();
    store.clearAll();

    store.setActiveAccountKey('account-a');
    store.save(
      stationId: 'station-a',
      formType: 'hourly',
      values: const {'temperature': 12},
    );

    store.setActiveAccountKey('account-b');
    store.save(
      stationId: 'station-b',
      formType: 'daily',
      values: const {'rainfall': 4},
    );

    store.setActiveAccountKey('account-a');
    expect(store.draftCount, 1);
    expect(store.stationsWithDrafts(), {'station-a'});
    expect(store.formTypesWithDrafts('station-a'), {'hourly'});
    expect(store.draftsForStation('station-b'), isEmpty);

    store.setActiveAccountKey('account-b');
    expect(store.draftCount, 1);
    expect(store.stationsWithDrafts(), {'station-b'});
    expect(store.formTypesWithDrafts('station-b'), {'daily'});
    expect(store.draftsForStation('station-a'), isEmpty);

    store.setActiveAccountKey(null);
    expect(store.draftCount, 0);
    expect(store.stationsWithDrafts(), isEmpty);
    expect(store.draftsForStation('station-a'), isEmpty);

    // Signed-out cleanup must not erase either account's private drafts.
    store.clearStation('station-a');
    store.clearActiveAccountMemory();
    store.setActiveAccountKey('account-a');
    expect(store.hasDraft('station-a', 'hourly'), isTrue);
    store.setActiveAccountKey('account-b');
    expect(store.hasDraft('station-b', 'daily'), isTrue);
  });
}
