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

  test('rejects additional credential and session field variants', () {
    ObservationDraftStore.instance.save(
      stationId: 'station-a',
      formType: 'hourly',
      values: {
        'temperature': 12,
        'private_key': 'key',
        'credential_blob': 'credential',
        'cookie_header': 'cookie',
        'session_id': 'session',
        'jwt': 'token',
        'bearer': 'token',
      },
    );
    final draft =
        ObservationDraftStore.instance.get('station-a', 'hourly');
    expect(draft, isNotNull);
    expect(draft!.values.containsKey('temperature'), isTrue);
    for (final key in [
      'private_key',
      'credential_blob',
      'cookie_header',
      'session_id',
      'jwt',
      'bearer',
    ]) {
      expect(draft.values.containsKey(key), isFalse, reason: key);
    }
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
