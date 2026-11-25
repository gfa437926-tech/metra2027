import 'package:flutter/foundation.dart';

/// Session-scoped local observation drafts.
///
/// Rules:
/// - Never stores passwords, tokens, or session secrets.
/// - Never claims server persistence.
/// - Cleared only after explicit successful server submit or user discard.
/// - Keyed by stationId + formType so drafts do not leak across stations.
class ObservationDraftStore extends ChangeNotifier {
  ObservationDraftStore._();

  static final ObservationDraftStore instance = ObservationDraftStore._();

  final Map<String, ObservationDraft> _drafts = {};

  static String keyFor(String stationId, String formType) =>
      '${stationId.trim()}::${formType.trim().toLowerCase()}';

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
  }

  void clear(String stationId, String formType) {
    if (stationId.trim().isEmpty || formType.trim().isEmpty) return;
    if (_drafts.remove(keyFor(stationId, formType)) != null) {
      notifyListeners();
    }
  }

  void clearStation(String stationId) {
    final id = stationId.trim();
    if (id.isEmpty) return;
    final before = _drafts.length;
    _drafts.removeWhere((_, draft) => draft.stationId == id);
    if (_drafts.length != before) {
      notifyListeners();
    }
  }

  /// Test / session reset helper.
  void clearAll() {
    if (_drafts.isEmpty) return;
    _drafts.clear();
    notifyListeners();
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

  static bool _isEffectivelyEmpty(Object? value) {
    if (value == null) return true;
    if (value is String && value.trim().isEmpty) return true;
    return false;
  }

  static bool _looksLikeSecret(String fieldId) {
    const blocked = [
      'password',
      'passwd',
      'secret',
      'token',
      'access_token',
      'refresh_token',
      'apikey',
      'api_key',
      'service_role',
      'authorization',
      'credential',
      'privatekey',
      'private_key',
      'cookie',
      'session',
      'jwt',
      'bearer',
    ];
    return blocked.any((b) => fieldId.contains(b));
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
}
