import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local observation drafts (session + optional on-device persistence).
///
/// Rules:
/// - Never stores passwords, tokens, or session secrets.
/// - Never claims server persistence.
/// - Cleared after explicit successful server submit, local catalog save, or user discard.
/// - Keyed by stationId + formType so drafts do not leak across stations.
class ObservationDraftStore extends ChangeNotifier {
  ObservationDraftStore._();

  static final ObservationDraftStore instance = ObservationDraftStore._();

  static const _prefsKey = 'metra2027.observation_drafts.v1';

  final Map<String, ObservationDraft> _drafts = {};
  bool _loaded = false;
  bool _loading = false;
  String? lastPersistError;

  static String keyFor(String stationId, String formType) =>
      '${stationId.trim()}::${formType.trim().toLowerCase()}';

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final draft = ObservationDraft.tryParse(value);
            if (draft != null && !draft.isEmpty) {
              _drafts['$key'] = draft;
            }
          });
        }
      }
    } catch (_) {
      // Keep memory empty rather than crashing; do not wipe disk.
    } finally {
      _loaded = true;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, Object?>{};
      _drafts.forEach((key, draft) {
        payload[key] = draft.toJson();
      });
      await prefs.setString(_prefsKey, jsonEncode(payload));
      if (lastPersistError != null) {
        lastPersistError = null;
        notifyListeners();
      }
    } catch (_) {
      lastPersistError =
          'تعذر حفظ المسودات على الجهاز. تبقى متاحة لهذه الجلسة فقط.';
      notifyListeners();
    }
  }

  ObservationDraft? get(String stationId, String formType) {
    if (stationId.trim().isEmpty || formType.trim().isEmpty) return null;
    return _drafts[keyFor(stationId, formType)];
  }

  /// Saves field values only. Rejects keys that look like secrets.
  void save({
    required String stationId,
    required String formType,
    required Map<String, Object?> values,
  }) {
    if (stationId.trim().isEmpty || formType.trim().isEmpty) return;
    final sanitized = <String, Object?>{};
    for (final entry in values.entries) {
      final id = entry.key.trim().toLowerCase();
      if (id.isEmpty) continue;
      if (_looksLikeSecret(id)) continue;
      if (_isEffectivelyEmpty(entry.value)) continue;
      sanitized[entry.key] = entry.value;
    }
    final key = keyFor(stationId, formType);
    if (sanitized.isEmpty) {
      if (_drafts.remove(key) != null) {
        notifyListeners();
        // ignore: unawaited_futures
        _persist();
      }
      return;
    }
    _drafts[key] = ObservationDraft(
      stationId: stationId.trim(),
      formType: formType.trim().toLowerCase(),
      values: Map.unmodifiable(sanitized),
      savedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  void clear(String stationId, String formType) {
    if (stationId.trim().isEmpty || formType.trim().isEmpty) return;
    if (_drafts.remove(keyFor(stationId, formType)) != null) {
      notifyListeners();
      // ignore: unawaited_futures
      _persist();
    }
  }

  void clearStation(String stationId) {
    final id = stationId.trim();
    if (id.isEmpty) return;
    final before = _drafts.length;
    _drafts.removeWhere((_, draft) => draft.stationId == id);
    if (_drafts.length != before) {
      notifyListeners();
      // ignore: unawaited_futures
      _persist();
    }
  }

  /// Test / session reset helper.
  void clearAll({bool persist = false}) {
    if (_drafts.isEmpty) return;
    _drafts.clear();
    notifyListeners();
    if (persist) {
      // ignore: unawaited_futures
      _persist();
    }
  }

  int get draftCount => _drafts.length;

  bool hasDraft(String stationId, String formType) {
    final draft = get(stationId, formType);
    return draft != null && !draft.isEmpty;
  }

  /// Station ids that currently hold at least one non-empty draft.
  Set<String> stationsWithDrafts() {
    final stations = <String>{};
    for (final draft in _drafts.values) {
      if (!draft.isEmpty) stations.add(draft.stationId);
    }
    return Set.unmodifiable(stations);
  }

  /// Form types with a non-empty draft for the given station.
  Set<String> formTypesWithDrafts(String stationId) {
    final id = stationId.trim();
    if (id.isEmpty) return const <String>{};
    final types = <String>{};
    for (final draft in _drafts.values) {
      if (draft.stationId == id && !draft.isEmpty) {
        types.add(draft.formType);
      }
    }
    return Set.unmodifiable(types);
  }

  /// Non-empty drafts for one station, newest first.
  List<ObservationDraft> draftsForStation(String stationId) {
    final id = stationId.trim();
    if (id.isEmpty) return const [];
    final list = _drafts.values
        .where((d) => d.stationId == id && !d.isEmpty)
        .toList(growable: false);
    final sorted = List<ObservationDraft>.of(list)
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return List.unmodifiable(sorted);
  }

  static bool _looksLikeSecret(String id) {
    return id.contains('password') ||
        id.contains('token') ||
        id.contains('secret') ||
        id.contains('apikey') ||
        id.contains('access_token') ||
        id.contains('refresh');
  }

  static bool _isEffectivelyEmpty(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }
}

class ObservationDraft {
  const ObservationDraft({
    required this.stationId,
    required this.formType,
    required this.values,
    required this.savedAt,
  });

  final String stationId;
  final String formType;
  final Map<String, Object?> values;
  final DateTime savedAt;

  bool get isEmpty => values.isEmpty;

  Map<String, Object?> toJson() => {
        'stationId': stationId,
        'formType': formType,
        'values': values,
        'savedAt': savedAt.toUtc().toIso8601String(),
      };

  static ObservationDraft? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final stationId = map['stationId']?.toString().trim() ?? '';
    final formType = map['formType']?.toString().trim().toLowerCase() ?? '';
    final savedAt = DateTime.tryParse('${map['savedAt'] ?? ''}');
    if (stationId.isEmpty || formType.isEmpty || savedAt == null) return null;
    final valuesRaw = map['values'];
    final values = <String, Object?>{};
    if (valuesRaw is Map) {
      valuesRaw.forEach((k, v) {
        final key = '$k'.trim();
        if (key.isEmpty) return;
        values[key] = v;
      });
    }
    return ObservationDraft(
      stationId: stationId,
      formType: formType,
      values: Map.unmodifiable(values),
      savedAt: savedAt.toUtc(),
    );
  }
}
