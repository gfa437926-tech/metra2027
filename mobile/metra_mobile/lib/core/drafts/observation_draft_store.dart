import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local observation drafts (session + on-device persistence).
///
/// Rules:
/// - Never stores passwords, tokens, or session secrets.
/// - Never claims server persistence.
/// - Keyed by stationId + formType (+ active account) so drafts do not leak.
class ObservationDraftStore extends ChangeNotifier {
  ObservationDraftStore._();

  @visibleForTesting
  ObservationDraftStore.forTesting() : this._();

  static final ObservationDraftStore instance = ObservationDraftStore._();

  static const _prefsKey = 'metra2027.observation_drafts.v2';
  static const _legacyPrefsKey = 'metra2027.observation_drafts.v1';

  final Map<String, ObservationDraft> _drafts = {};
  final Set<String> _dirtyKeys = <String>{};
  bool _loaded = false;
  Future<void>? _loadFuture;
  Future<void> _persistTail = Future<void>.value();
  int _writeGeneration = 0;
  DateTime? _pendingClearAllBefore;
  bool _pendingClearAllPersist = false;
  bool _diskTrusted = true;
  String? _activeAccountKey;
  String? lastPersistError;

  static String keyFor(String stationId, String formType, {String? accountKey}) {
    final station = stationId.trim();
    final type = formType.trim().toLowerCase();
    final account = accountKey?.trim() ?? '';
    if (account.isEmpty) return '$station::$type';
    return '$account::$station::$type';
  }

  bool get isLoaded => _loaded;
  String? get activeAccountKey => _activeAccountKey;

  void setActiveAccountKey(String? key) {
    final next = key?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (_activeAccountKey == normalized) return;
    _activeAccountKey = normalized;
    notifyListeners();
  }

  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;
    final future = _loadFromDisk();
    _loadFuture = future;
    return future;
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_prefsKey);
      raw ??= prefs.getString(_legacyPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) {
            _diskTrusted = false;
          } else {
            decoded.forEach((key, value) {
              final draft = ObservationDraft.tryParse(value);
              if (draft != null && !draft.isEmpty) {
                final mapKey = keyFor(
                  draft.stationId,
                  draft.formType,
                  accountKey: draft.accountKey,
                );
                final clearBefore = _pendingClearAllBefore;
                if (clearBefore != null && !draft.savedAt.isAfter(clearBefore)) {
                  _dirtyKeys.add(mapKey);
                } else if (!_dirtyKeys.contains(mapKey)) {
                  _drafts[mapKey] = draft;
                }
              } else {
                _diskTrusted = false;
              }
            });
          }
        } catch (_) {
          // Preserve malformed storage rather than replacing it with partial data.
          _diskTrusted = false;
        }
      }
    } catch (_) {
      _diskTrusted = false;
    } finally {
      _loaded = true;
      _loadFuture = null;
      final clearBefore = _pendingClearAllBefore;
      if (clearBefore != null) {
        _drafts.removeWhere((key, draft) {
          final shouldClear = !draft.savedAt.isAfter(clearBefore);
          if (shouldClear) _dirtyKeys.add(key);
          return shouldClear;
        });
        _pendingClearAllBefore = null;
      }
      final persistClear = _pendingClearAllPersist;
      _pendingClearAllPersist = false;
      notifyListeners();
      if (persistClear && _diskTrusted) {
        // ignore: unawaited_futures
        _persist();
      }
    }
  }

  Future<void> _persist() async {
    // Resolve the existing disk snapshot before writing, otherwise a save
    // issued during startup could replace drafts that have not been loaded.
    await ensureLoaded();
    if (!_diskTrusted) return;

    final generation = ++_writeGeneration;
    final payload = <String, Object?>{};
    _drafts.forEach((key, draft) {
      payload[key] = draft.toJson();
    });
    final encoded = jsonEncode(payload);

    // Serialize writes. If an older write is already in progress, the newer
    // snapshot runs after it and becomes the final on-disk state.
    final operation = _persistTail.then((_) async {
      if (generation != _writeGeneration) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        if (generation != _writeGeneration) return;
        await prefs.setString(_prefsKey, encoded);
        if (generation != _writeGeneration) return;
        _dirtyKeys.clear();
        if (lastPersistError != null) {
          lastPersistError = null;
          notifyListeners();
        }
      } catch (_) {
        if (generation != _writeGeneration) return;
        lastPersistError =
            'تعذر حفظ المسودات على الجهاز. تبقى متاحة لهذه الجلسة فقط.';
        notifyListeners();
      }
    });
    _persistTail = operation;
    await operation;
  }

  bool _isVisibleDraft(ObservationDraft draft) {
    final account = _activeAccountKey;
    if (account == null) {
      return draft.accountKey == null || draft.accountKey!.isEmpty;
    }
    return draft.accountKey == account;
  }

  ObservationDraft? get(String stationId, String formType) {
    if (stationId.trim().isEmpty || formType.trim().isEmpty) return null;
    return _drafts[keyFor(
      stationId,
      formType,
      accountKey: _activeAccountKey,
    )];
  }

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
    final key = keyFor(stationId, formType, accountKey: _activeAccountKey);
    _dirtyKeys.add(key);
    if (sanitized.isEmpty) {
      final removed = _drafts.remove(key) != null;
      if (removed) notifyListeners();
      if (!_loaded || removed) {
        // Treat an empty save as a clear, including when the old draft has
        // not been loaded into memory yet.
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
      accountKey: _activeAccountKey,
    );
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
  }

  void clear(String stationId, String formType) {
    if (stationId.trim().isEmpty || formType.trim().isEmpty) return;
    final key = keyFor(stationId, formType, accountKey: _activeAccountKey);
    if (!_loaded) {
      // Remove an in-memory value immediately, and mark the key dirty even
      // when it is not loaded yet so the disk read cannot resurrect it.
      _dirtyKeys.add(key);
      if (_drafts.remove(key) != null) notifyListeners();
      // ignore: unawaited_futures
      _persist();
      return;
    }
    if (_drafts.remove(key) != null) {
      _dirtyKeys.add(key);
      notifyListeners();
      // ignore: unawaited_futures
      _persist();
    }
  }

  void clearStation(String stationId) {
    final id = stationId.trim();
    if (id.isEmpty) return;
    if (!_loaded) {
      final accountAtRequest = _activeAccountKey;
      final requestedAt = DateTime.now().toUtc();
      // Wait for the initial snapshot, then remove only drafts that existed
      // when this clear was requested. A later save remains intact.
      // ignore: unawaited_futures
      ensureLoaded().then((_) {
        final before = _drafts.length;
        _drafts.removeWhere((key, draft) {
          final belongsToAccount = accountAtRequest == null
              ? draft.accountKey == null || draft.accountKey!.isEmpty
              : draft.accountKey == accountAtRequest;
          final shouldClear = draft.stationId == id &&
              belongsToAccount &&
              !draft.savedAt.isAfter(requestedAt);
          if (shouldClear) _dirtyKeys.add(key);
          return shouldClear;
        });
        if (_drafts.length != before) notifyListeners();
        // Persist even if the disk-only rows were removed during load.
        // ignore: unawaited_futures
        _persist();
      });
      return;
    }
    final before = _drafts.length;
    _drafts.removeWhere((key, draft) {
      if (draft.stationId != id) return false;
      final matchesAccount = _isVisibleDraft(draft);
      if (matchesAccount) _dirtyKeys.add(key);
      return matchesAccount;
    });
    if (_drafts.length != before) {
      notifyListeners();
      // ignore: unawaited_futures
      _persist();
    }
  }

  /// Drops in-memory drafts for the active account only (keeps other accounts).
  void clearActiveAccountMemory() {
    if (_activeAccountKey == null) return;
    final before = _drafts.length;
    _drafts.removeWhere((_, d) => d.accountKey == _activeAccountKey);
    if (_drafts.length != before) notifyListeners();
  }

  void clearAll({bool persist = false}) {
    if (!_loaded) {
      final requestedAt = DateTime.now().toUtc();
      _pendingClearAllBefore = requestedAt;
      _pendingClearAllPersist = _pendingClearAllPersist || persist;
      final before = _drafts.length;
      _drafts.removeWhere((key, draft) {
        final shouldClear = !draft.savedAt.isAfter(requestedAt);
        if (shouldClear) _dirtyKeys.add(key);
        return shouldClear;
      });
      if (_drafts.length != before) notifyListeners();
      // The initial load applies the pending clear before any queued write.
      // ignore: unawaited_futures
      ensureLoaded();
      return;
    }
    if (_drafts.isEmpty) return;
    _dirtyKeys.addAll(_drafts.keys);
    _drafts.clear();
    notifyListeners();
    if (persist) {
      // ignore: unawaited_futures
      _persist();
    }
  }

  int get draftCount => _drafts.values.where(_isVisibleDraft).length;

  bool hasDraft(String stationId, String formType) {
    final draft = get(stationId, formType);
    return draft != null && !draft.isEmpty;
  }

  Set<String> stationsWithDrafts() {
    final stations = <String>{};
    for (final draft in _drafts.values) {
      if (draft.isEmpty) continue;
      if (!_isVisibleDraft(draft)) continue;
      stations.add(draft.stationId);
    }
    return Set.unmodifiable(stations);
  }

  Set<String> formTypesWithDrafts(String stationId) {
    final id = stationId.trim();
    if (id.isEmpty) return const <String>{};
    final types = <String>{};
    for (final draft in _drafts.values) {
      if (draft.stationId != id || draft.isEmpty) continue;
      if (!_isVisibleDraft(draft)) continue;
      types.add(draft.formType);
    }
    return Set.unmodifiable(types);
  }

  List<ObservationDraft> draftsForStation(String stationId) {
    final id = stationId.trim();
    if (id.isEmpty) return const [];
    final list = _drafts.values.where((d) {
      if (d.stationId != id || d.isEmpty) return false;
      return _isVisibleDraft(d);
    }).toList(growable: false);
    final sorted = List<ObservationDraft>.of(list)
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return List.unmodifiable(sorted);
  }

  /// Explicit claim of a legacy (null-account) draft into the active account.
  bool claimUnassignedDraft(String stationId, String formType) {
    final account = _activeAccountKey;
    if (account == null || account.isEmpty) return false;
    final legacyKey = keyFor(stationId, formType, accountKey: null);
    final draft = _drafts[legacyKey];
    if (draft == null || draft.isEmpty) return false;
    final claimedKey = keyFor(stationId, formType, accountKey: account);
    if (_drafts.containsKey(claimedKey)) return false; // no overwrite
    _drafts.remove(legacyKey);
    _dirtyKeys.addAll([legacyKey, claimedKey]);
    _drafts[claimedKey] = ObservationDraft(
      stationId: draft.stationId,
      formType: draft.formType,
      values: draft.values,
      savedAt: DateTime.now().toUtc(),
      accountKey: account,
    );
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
    return true;
  }

  List<ObservationDraft> listUnassignedDrafts() {
    final list = _drafts.values
        .where((d) => !d.isEmpty && (d.accountKey == null || d.accountKey!.isEmpty))
        .toList(growable: false);
    list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return List.unmodifiable(list);
  }

  static bool _looksLikeSecret(String id) {
    final normalized = id.trim().toLowerCase().replaceAll('-', '_');
    if (normalized.isEmpty) return false;
    const markers = <String>[
      'password',
      'token',
      'secret',
      'apikey',
      'api_key',
      'access_token',
      'refresh',
      'session',
      'jwt',
      'bearer',
      'private_key',
      'privatekey',
      'credential',
      'authorization',
    ];
    for (final marker in markers) {
      if (normalized.contains(marker)) return true;
    }
    return false;
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
    this.accountKey,
  });

  final String stationId;
  final String formType;
  final Map<String, Object?> values;
  final DateTime savedAt;
  final String? accountKey;

  bool get isEmpty => values.isEmpty;

  Map<String, Object?> toJson() => {
        'stationId': stationId,
        'formType': formType,
        'values': values,
        'savedAt': savedAt.toUtc().toIso8601String(),
        if (accountKey != null && accountKey!.isNotEmpty) 'accountKey': accountKey,
      };

  static ObservationDraft? tryParse(Object? raw) {
    if (raw is! Map) return null;
    late final Map<String, dynamic> map;
    try {
      map = Map<String, dynamic>.from(raw);
    } on TypeError {
      return null;
    }
    final stationRaw = map['stationId'];
    final formRaw = map['formType'];
    final savedAtRaw = map['savedAt'];
    if (stationRaw is! String ||
        formRaw is! String ||
        savedAtRaw is! String) {
      return null;
    }
    final stationId = stationRaw.trim();
    final formType = formRaw.trim().toLowerCase();
    final savedAt = DateTime.tryParse(savedAtRaw);
    if (stationId.isEmpty || formType.isEmpty || savedAt == null) return null;

    final valuesRaw = map['values'];
    if (valuesRaw is! Map) return null;
    final values = <String, Object?>{};
    for (final entry in valuesRaw.entries) {
      if (entry.key is! String) return null;
      final key = (entry.key as String).trim();
      if (key.isEmpty || values.containsKey(key)) return null;
      values[key] = entry.value;
    }

    final accountRaw = map['accountKey'];
    if (accountRaw != null && accountRaw is! String) return null;
    final accountKey = (accountRaw as String?)?.trim();
    return ObservationDraft(
      stationId: stationId,
      formType: formType,
      values: Map.unmodifiable(values),
      savedAt: savedAt.toUtc(),
      accountKey: (accountKey == null || accountKey.isEmpty) ? null : accountKey,
    );
  }
}
