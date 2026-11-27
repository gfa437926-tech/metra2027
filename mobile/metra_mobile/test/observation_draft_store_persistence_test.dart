import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metra_mobile/core/drafts/observation_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saving before initial load preserves unrelated persisted drafts', () async {
    final oldDraft = ObservationDraft(
      stationId: 'station-old',
      formType: 'hourly',
      values: const {'temperature': 14},
      savedAt: DateTime.utc(2026, 11, 26),
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.observation_drafts.v2': jsonEncode({
        'station-old::hourly': oldDraft.toJson(),
      }),
    });

    final store = ObservationDraftStore.instance;
    store.save(
      stationId: 'station-new',
      formType: 'daily',
      values: const {'rainfall': 3},
    );
    await store.ensureLoaded();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('metra2027.observation_drafts.v2');
    expect(raw, isNotNull);
    final persisted = jsonDecode(raw!) as Map<String, dynamic>;
    expect(persisted, contains('station-old::hourly'));
    expect(persisted, contains('station-new::daily'));
  });
  test('clearing before initial load removes the persisted draft', () async {
    final oldDraft = ObservationDraft(
      stationId: 'station-clear',
      formType: 'hourly',
      values: const {'temperature': 18},
      savedAt: DateTime.utc(2026, 11, 26),
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.observation_drafts.v2': jsonEncode({
        'station-clear::hourly': oldDraft.toJson(),
      }),
    });

    final store = ObservationDraftStore.forTesting();
    store.clear('station-clear', 'hourly');
    await store.ensureLoaded();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('metra2027.observation_drafts.v2');
    expect(raw, isNotNull);
    expect(jsonDecode(raw!), isEmpty);
    expect(store.get('station-clear', 'hourly'), isNull);
  });

  test('clearing a station before initial load removes its persisted drafts', () async {
    final oldDraft = ObservationDraft(
      stationId: 'station-clear-all',
      formType: 'daily',
      values: const {'rainfall': 8},
      savedAt: DateTime.utc(2026, 11, 26),
    );
    SharedPreferences.setMockInitialValues({
      'metra2027.observation_drafts.v2': jsonEncode({
        'station-clear-all::daily': oldDraft.toJson(),
      }),
    });

    final store = ObservationDraftStore.forTesting();
    store.clearStation('station-clear-all');
    await store.ensureLoaded();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('metra2027.observation_drafts.v2');
    expect(raw, isNotNull);
    expect(jsonDecode(raw!), isEmpty);
    expect(store.draftsForStation('station-clear-all'), isEmpty);
  });

}
