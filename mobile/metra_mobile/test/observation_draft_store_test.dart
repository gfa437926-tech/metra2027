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

  test('hasDraft and stationsWithDrafts isolate by station', () {
    final store = ObservationDraftStore.instance;
    store.save(stationId: 's1', formType: 'rainfall', values: {'a': 1});
    store.save(stationId: 's2', formType: 'soil', values: {'b': 2});
    expect(store.hasDraft('s1', 'rainfall'), isTrue);
    expect(store.hasDraft('s1', 'soil'), isFalse);
    expect(store.stationsWithDrafts(), containsAll(['s1', 's2']));
    store.clearStation('s1');
    expect(store.hasDraft('s1', 'rainfall'), isFalse);
    expect(store.hasDraft('s2', 'soil'), isTrue);
  });

  test('blank station or form type is ignored', () {
    ObservationDraftStore.instance.save(
      stationId: '  ',
      formType: 'hourly',
      values: {'dryTemp': 1},
    );
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: '',
      values: {'dryTemp': 1},
    );
    expect(ObservationDraftStore.instance.draftCount, 0);
  });

  test('overwrite replaces values for same station and form', () {
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'phenomenon',
      values: {'code': 'old'},
    );
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'phenomenon',
      values: {'code': 'new', 'intensity': 2},
    );
    final draft =
        ObservationDraftStore.instance.get('station-a', 'phenomenon');
    expect(draft!.values['code'], 'new');
    expect(draft.values['intensity'], 2);
    expect(draft.values.containsKey('dryTemp'), isFalse);
  });

  test('form type key is case-insensitive', () {
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'Hourly',
      values: {'dryTemp': 9},
    );
    expect(
      ObservationDraftStore.instance.get('station-a', 'hourly')!.values['dryTemp'],
      9,
    );
  });

  test('seven catalogue form types do not collide', () {
    const types = [
      'agricultural',
      'hourlyclimate',
      'rainfall',
      'soil',
      'faultequipment',
      'faulttelecom',
      'faultit',
    ];
    for (var i = 0; i < types.length; i++) {
      ObservationDraftStore.instance.save(
        stationId: 'station-a',
        formType: types[i],
        values: {'idx': i},
      );
    }
    expect(ObservationDraftStore.instance.draftCount, types.length);
    for (var i = 0; i < types.length; i++) {
      expect(
        ObservationDraftStore.instance.get('station-a', types[i])!.values['idx'],
        i,
      );
    }
  });

  test('whitespace-only values do not keep a draft', () {
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'hourly',
      values: {'dryTemp': '  ', 'note': ''},
    );
    expect(ObservationDraftStore.instance.get('station-a', 'hourly'), isNull);
  });

  test('false boolean is preserved as a real value', () {
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'daily',
      values: {'flag': false},
    );
    expect(
      ObservationDraftStore.instance.get('station-a', 'daily')!.values['flag'],
      isFalse,
    );
  });

  test('clearStation does not wipe stations that only share a prefix', () {
    ObservationDraftStore.instance.save(
      stationId: 'st',
      formType: 'hourly',
      values: {'dryTemp': 1},
    );
    ObservationDraftStore.instance.save(
      stationId: 'st2',
      formType: 'hourly',
      values: {'dryTemp': 2},
    );
    ObservationDraftStore.instance.clearStation('st');
    expect(ObservationDraftStore.instance.get('st', 'hourly'), isNull);
    expect(
      ObservationDraftStore.instance.get('st2', 'hourly')!.values['dryTemp'],
      2,
    );
  });

  test('failed validation scenario: draft remains after save without clear', () {
    // Screens must not clear on validation failure; store itself only clears on
    // explicit clear/save-empty.
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'hourly',
      values: {'dryTemp': 18},
    );
    expect(ObservationDraftStore.instance.hasDraft('station-a', 'hourly'), isTrue);
    // Simulate failed submit: no clear called.
    expect(
      ObservationDraftStore.instance.get('station-a', 'hourly')!.values['dryTemp'],
      18,
    );
  });

}
