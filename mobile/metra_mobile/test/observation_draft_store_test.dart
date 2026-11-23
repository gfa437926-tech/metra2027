import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/drafts/observation_draft_store.dart';

void main() {
  setUp(() {
    ObservationDraftStore.instance.clearAll();
  });

  test('saves and restores draft per station and form type', () {
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'hourly',
      values: {'dryTemp': 12.5, 'windSpeed': 3},
    );

    final draft =
        ObservationDraftStore.instance.get('station-a', 'hourly');
    expect(draft, isNotNull);
    expect(draft!.values['dryTemp'], 12.5);
    expect(draft.values['windSpeed'], 3);
    expect(
      ObservationDraftStore.instance.get('station-b', 'hourly'),
      isNull,
    );
    expect(
      ObservationDraftStore.instance.get('station-a', 'daily'),
      isNull,
    );
  });

  test('rejects secret-looking field ids', () {
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'hourly',
      values: {
        'dryTemp': 10,
        'password': 'secret',
        'access_token': 'tok',
        'api_key': 'k',
      },
    );
    final draft =
        ObservationDraftStore.instance.get('station-a', 'hourly');
    expect(draft, isNotNull);
    expect(draft!.values.containsKey('dryTemp'), isTrue);
    expect(draft.values.containsKey('password'), isFalse);
    expect(draft.values.containsKey('access_token'), isFalse);
    expect(draft.values.containsKey('api_key'), isFalse);
  });

  test('clear removes only the targeted draft', () {
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'hourly',
      values: {'dryTemp': 1},
    );
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'daily',
      values: {'minTemp': 2},
    );
    ObservationDraftStore.instance.clear('station-a', 'hourly');
    expect(
      ObservationDraftStore.instance.get('station-a', 'hourly'),
      isNull,
    );
    expect(
      ObservationDraftStore.instance.get('station-a', 'daily'),
      isNotNull,
    );
  });

  test('empty values clear the draft', () {
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'hourly',
      values: {'dryTemp': 1},
    );
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'hourly',
      values: const {},
    );
    expect(
      ObservationDraftStore.instance.get('station-a', 'hourly'),
      isNull,
    );
  });
}

  test('hasDraft and stationsWithDrafts isolate by station', () {
    final store = ObservationDraftStore.instance;
    store.clearAll();
    store.save(stationId: 's1', formType: 'rainfall', values: {'a': 1});
    store.save(stationId: 's2', formType: 'soil', values: {'b': 2});
    expect(store.hasDraft('s1', 'rainfall'), isTrue);
    expect(store.hasDraft('s1', 'soil'), isFalse);
    expect(store.stationsWithDrafts(), containsAll(['s1', 's2']));
    store.clearStation('s1');
    expect(store.hasDraft('s1', 'rainfall'), isFalse);
    expect(store.hasDraft('s2', 'soil'), isTrue);
    store.clearAll();
  });
