/// Session-scoped local observation drafts.
///
/// Rules:
/// - Never stores passwords, tokens, or session secrets.
/// - Never claims server persistence.
/// - Cleared only after explicit successful server submit or user discard.
/// - Keyed by stationId + formType so drafts do not leak across stations.
class ObservationDraftStore {
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
      sanitized[entry.key] = entry.value;
    }
    if (sanitized.isEmpty) {
      clear(stationId, formType);
      return;
    }
    _drafts[keyFor(stationId, formType)] = ObservationDraft(
      stationId: stationId.trim(),
      formType: formType.trim().toLowerCase(),
      values: Map.unmodifiable(sanitized),
      savedAt: DateTime.now().toUtc(),
    );
  }

  void clear(String stationId, String formType) {
    if (stationId.trim().isEmpty || formType.trim().isEmpty) return;
    _drafts.remove(keyFor(stationId, formType));
  }

  void clearStation(String stationId) {
    final prefix = '${stationId.trim()}::';
    _drafts.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Test / session reset helper.
  void clearAll() => _drafts.clear();

  int get draftCount => _drafts.length;

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
