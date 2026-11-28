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

    final draft = ObservationDraftStore.instance.get('station-a', 'hourly');
    expect(draft, isNotNull);
    expect(draft!.values['dryTemp'], 12.5);
    expect(draft.values['windSpeed'], 3);
    expect(ObservationDraftStore.instance.get('station-b', 'hourly'), isNull);
    expect(ObservationDraftStore.instance.get('station-a', 'daily'), isNull);
  });

  test('station isolation: drafts do not leak across stations', () {
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'hourly',
      values: {'dryTemp': 1},
    );
    ObservationDraftStore.instance.save(
      stationId: 'station-b',
      formType: 'hourly',
      values: {'dryTemp': 2},
    );
    expect(
      ObservationDraftStore.instance
          .get('station-a', 'hourly')!
          .values['dryTemp'],
      1,
    );
    expect(
      ObservationDraftStore.instance
          .get('station-b', 'hourly')!
          .values['dryTemp'],
      2,
    );
  });

  test('clear removes only the targeted station/form draft', () {
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'hourly',
      values: {'dryTemp': 1},
    );
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'daily',
      values: {'maxTemp': 2},
    );
    ObservationDraftStore.instance.clear('station-a', 'hourly');
    expect(ObservationDraftStore.instance.get('station-a', 'hourly'), isNull);
    expect(ObservationDraftStore.instance.get('station-a', 'daily'), isNotNull);
  });

  test(
    'failed validation scenario: draft remains after save without clear',
    () {
      ObservationDraftStore.instance.save(
        stationId: 'station-a',
        formType: 'hourly',
        values: {'dryTemp': 18},
      );
      expect(
        ObservationDraftStore.instance.hasDraft('station-a', 'hourly'),
        isTrue,
      );
      expect(
        ObservationDraftStore.instance
            .get('station-a', 'hourly')!
            .values['dryTemp'],
        18,
      );
    },
  );

  test('expanded secret field names are never stored', () {
    ObservationDraftStore.instance.save(
      stationId: 'st-1',
      formType: 'hourly',
      values: {
        'temp': 12,
        'session_id': 'x',
        'jwt_token': 'y',
        'bearer_header': 'z',
        'private_key': 'no',
      },
    );
    final draft = ObservationDraftStore.instance.get('st-1', 'hourly');
    expect(draft, isNotNull);
    expect(draft!.values.containsKey('temp'), isTrue);
    expect(draft.values.containsKey('session_id'), isFalse);
    expect(draft.values.containsKey('jwt_token'), isFalse);
    expect(draft.values.containsKey('bearer_header'), isFalse);
    expect(draft.values.containsKey('private_key'), isFalse);
  });

  test('formTypesWithDrafts returns only non-empty types for station', () {
    ObservationDraftStore.instance.save(
      stationId: 'st-a',
      formType: 'hourly',
      values: {'t': 1},
    );
    ObservationDraftStore.instance.save(
      stationId: 'st-a',
      formType: 'daily',
      values: {'t': 2},
    );
    ObservationDraftStore.instance.save(
      stationId: 'st-b',
      formType: 'hourly',
      values: {'t': 3},
    );
    final types = ObservationDraftStore.instance.formTypesWithDrafts('st-a');
    expect(types, containsAll(['hourly', 'daily']));
    expect(types.contains('phenomenon'), isFalse);
    expect(
      ObservationDraftStore.instance.formTypesWithDrafts('st-b'),
      equals({'hourly'}),
    );
  });

  test('draftsForStation returns newest-first non-empty drafts only', () {
    ObservationDraftStore.instance.save(
      stationId: 'st-x',
      formType: 'hourly',
      values: {'t': 1},
    );
    ObservationDraftStore.instance.save(
      stationId: 'st-x',
      formType: 'daily',
      values: {'t': 2},
    );
    ObservationDraftStore.instance.save(
      stationId: 'st-y',
      formType: 'hourly',
      values: {'t': 3},
    );
    final list = ObservationDraftStore.instance.draftsForStation('st-x');
    expect(list.length, 2);
    expect(list.every((d) => d.stationId == 'st-x'), isTrue);
    expect(ObservationDraftStore.instance.draftsForStation('missing'), isEmpty);
  });

  test('notifies listeners on save and clear', () {
    var ticks = 0;
    void listener() => ticks++;
    final store = ObservationDraftStore.instance;
    store.addListener(listener);
    store.save(stationId: 'st-n', formType: 'hourly', values: {'t': 1});
    expect(ticks, 1);
    store.clear('st-n', 'hourly');
    expect(ticks, 2);
    store.removeListener(listener);
  });
  test('rejects malformed draft maps with non-string keys safely', () {
    final malformed = <Object, Object?>{4: 'invalid-key'};
    expect(ObservationDraft.tryParse(malformed), isNull);
  });

  test('rejects draft identity fields with non-string types', () {
    final base = {
      'stationId': 'station-a',
      'formType': 'hourly',
      'savedAt': DateTime.utc(2026, 11, 27).toIso8601String(),
      'values': {'temperature': 12},
    };
    for (final entry in {
      'stationId': 42,
      'formType': true,
      'savedAt': 20261127,
      'accountKey': 99,
    }.entries) {
      final malformed = Map<String, Object?>.from(base)..[entry.key] = entry.value;
      expect(
        ObservationDraft.tryParse(malformed),
        isNull,
        reason: entry.key,
      );
    }
  });

  test('rejects malformed values maps and normalized duplicate keys', () {
    final base = {
      'stationId': 'station-a',
      'formType': 'hourly',
      'savedAt': DateTime.utc(2026, 11, 27).toIso8601String(),
    };
    expect(
      ObservationDraft.tryParse({...base, 'values': 'not-a-map'}),
      isNull,
    );
    expect(
      ObservationDraft.tryParse({
        ...base,
        'values': {' temperature ': 12, 'temperature': 13},
      }),
      isNull,
    );
    expect(
      ObservationDraft.tryParse({...base, 'values': { '   ': 12 }}),
      isNull,
    );
  });

}
