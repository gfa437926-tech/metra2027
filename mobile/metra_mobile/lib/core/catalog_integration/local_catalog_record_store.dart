import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_catalog_record.dart';

/// Result of a partial recovery load from disk.
class LocalCatalogLoadReport {
  const LocalCatalogLoadReport({
    required this.loaded,
    required this.skippedCorrupt,
  });

  final int loaded;
  final int skippedCorrupt;
}

/// On-device catalogue records (session + SharedPreferences).
///
/// Never syncs to the server. Labels remain "local only".
class LocalCatalogRecordStore extends ChangeNotifier {
  LocalCatalogRecordStore._();

  @visibleForTesting
  LocalCatalogRecordStore.forTesting();

  static final LocalCatalogRecordStore instance = LocalCatalogRecordStore._();

  static const _prefsKey = 'metra2027.local_catalog_records.v1';
  static const _prefsMetaKey = 'metra2027.local_catalog_records.meta.v1';

  final Map<String, LocalCatalogRecord> _byId = {};
  bool _loaded = false;
  bool _loading = false;
  Future<LocalCatalogLoadReport>? _loadFuture;
  Future<void> _persistTail = Future<void>.value();
  final Set<String> _dirtyIds = <String>{};
  bool _diskTrusted = true;
  int _lastSkippedCorrupt = 0;
  String? _activeAccountKey;
  String? lastPersistError;
  int _writeGeneration = 0;

  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  int get count => _byId.values.where(_canAccessRecord).length;
  int get lastSkippedCorrupt => _lastSkippedCorrupt;

  /// Optional account scope applied to new writes (auth user id).
  void setActiveAccountKey(String? key) {
    final next = key?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (_activeAccountKey == normalized) return;
    _activeAccountKey = normalized;
    notifyListeners();
  }

  String? get activeAccountKey => _activeAccountKey;

  Future<LocalCatalogLoadReport> ensureLoaded() {
    if (_loaded) {
      return Future.value(
        LocalCatalogLoadReport(
          loaded: _byId.length,
          skippedCorrupt: _lastSkippedCorrupt,
        ),
      );
    }
    return _loadFuture ??= _loadFromDisk();
  }

  Future<LocalCatalogLoadReport> _loadFromDisk() async {
    _loading = true;
    var skipped = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        Object? decoded;
        var payloadTrusted = true;
        try {
          decoded = jsonDecode(raw);
        } catch (_) {
          skipped = 1;
          payloadTrusted = false;
        }
        if (decoded is List) {
          for (final item in decoded) {
            final record = LocalCatalogRecord.tryParse(item);
            if (record == null) {
              skipped++;
              payloadTrusted = false;
              continue;
            }
            if (_dirtyIds.contains(record.id)) continue;
            final existing = _byId[record.id];
            if (existing == null ||
                record.updatedAt.isAfter(existing.updatedAt)) {
              _byId[record.id] = record;
            }
          }
        } else if (decoded is Map) {
          final record = LocalCatalogRecord.tryParse(decoded);
          if (record != null) {
            if (!_dirtyIds.contains(record.id)) {
              _byId[record.id] = record;
            }
          } else {
            skipped++;
            payloadTrusted = false;
          }
        } else if (decoded != null) {
          skipped++;
          payloadTrusted = false;
        } else {
          payloadTrusted = false;
        }
        _diskTrusted = payloadTrusted;
      }
    } catch (_) {
      _diskTrusted = false;
    } finally {
      _lastSkippedCorrupt = skipped;
      _loaded = true;
      _loading = false;
      notifyListeners();
    }
    return LocalCatalogLoadReport(
      loaded: _byId.length,
      skippedCorrupt: skipped,
    );
  }

  Future<void> _persist() {
    final generation = ++_writeGeneration;
    final write = _persistTail.then((_) async {
      await ensureLoaded();
      if (!_diskTrusted || generation != _writeGeneration) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final payload =
            _byId.values.map((r) => r.toJson()).toList(growable: false);
        if (generation != _writeGeneration) return;
        await prefs.setString(_prefsKey, jsonEncode(payload));
        if (generation != _writeGeneration) return;
        await prefs.setString(
          _prefsMetaKey,
          jsonEncode({
            'schemaVersion': LocalCatalogRecord.currentSchemaVersion,
            'count': payload.length,
            'writtenAt': DateTime.now().toUtc().toIso8601String(),
          }),
        );
        if (generation != _writeGeneration) return;
        _dirtyIds.clear();
        _diskTrusted = true;
        if (lastPersistError != null) {
          lastPersistError = null;
          notifyListeners();
        }
      } catch (_) {
        if (generation != _writeGeneration) return;
        lastPersistError =
            'تعذر حفظ السجلات المحلية على الجهاز. تبقى متاحة لهذه الجلسة فقط.';
        notifyListeners();
      }
    });
    _persistTail = write.catchError((_) {});
    return write;
  }

  @visibleForTesting
  Future<void> flushForTesting() => _persist();

  bool _canAccessRecord(LocalCatalogRecord record) {
    final active = _activeAccountKey;
    if (active == null) {
      return record.accountKey == null || record.accountKey!.isEmpty;
    }
    return record.accountKey == active;
  }

  /// Create or update by stable [id]. Empty id creates a new record.
  /// Existing records are writable only by their owning active account.
  LocalCatalogRecord upsert({
    String? id,
    required String stationId,
    required String formType,
    required Map<String, Object?> values,
    String? accountKey,
  }) {
    final now = DateTime.now().toUtc();
    final station = stationId.trim();
    final type = formType.trim().toLowerCase();
    if (station.isEmpty || type.isEmpty) {
      throw ArgumentError('stationId and formType are required');
    }
    if (!_loaded && id?.trim().isNotEmpty == true) {
      throw StateError(
        'cannot use a caller-supplied record id before the local catalogue is loaded',
      );
    }
    final recordId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : 'local-$type-${now.microsecondsSinceEpoch}';
    final existing = _byId[recordId];
    if (existing != null && !_canAccessRecord(existing)) {
      throw StateError('cannot modify a local record owned by another account');
    }
    final requestedAccount = accountKey?.trim();
    if (requestedAccount != null && requestedAccount.isNotEmpty && requestedAccount != _activeAccountKey) {
      throw StateError('local record account must match the active account');
    }
    // Identity lock: cannot change station/formType of an existing id.
    if (existing != null) {
      if (existing.stationId != station || existing.formType != type) {
        throw StateError(
          'cannot reassign station/formType for existing local record $recordId',
        );
      }
    }
    final resolvedAccount = _activeAccountKey;
    final next = LocalCatalogRecord(
      id: recordId,
      stationId: station,
      formType: type,
      values: Map.unmodifiable(Map<String, Object?>.from(values)),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: LocalCatalogRecordStatus.localSaved,
      accountKey: resolvedAccount,
    );
    _byId[recordId] = next;
    _dirtyIds.add(recordId);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
    return next;
  }

  bool archive(String id) {
    final current = _byId[id];
    if (current == null || !_canAccessRecord(current)) return false;
    _dirtyIds.add(id);
    _byId[id] = current.copyWith(
      status: LocalCatalogRecordStatus.localArchived,
      updatedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
    return true;
  }

  /// Move an archived local record back to localSaved (same id).
  bool restore(String id) {
    final current = _byId[id];
    if (current == null || !_canAccessRecord(current)) return false;
    if (current.status != LocalCatalogRecordStatus.localArchived) {
      return false;
    }
    _dirtyIds.add(id);
    _byId[id] = current.copyWith(
      status: LocalCatalogRecordStatus.localSaved,
      updatedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
    return true;
  }

  bool delete(String id) {
    final current = _byId[id];
    if (current == null || !_canAccessRecord(current)) return false;
    final removed = _byId.remove(id) != null;
    if (removed) _dirtyIds.add(id);
    if (removed) {
      notifyListeners();
      // ignore: unawaited_futures
      _persist();
    }
    return removed;
  }

  LocalCatalogRecord? getById(String id) {
    final record = _byId[id];
    return record != null && _canAccessRecord(record) ? record : null;
  }

  List<LocalCatalogRecord> list({
    String? stationId,
    String? formType,
    String? query,
    String? accountKey,
    bool includeArchived = false,
  }) {
    // An explicit account override must never bypass the authenticated scope.
    if (accountKey != null && accountKey.trim() != (_activeAccountKey ?? '')) {
      return const <LocalCatalogRecord>[];
    }
    return LocalCatalogRecordQuery.filter(
      records: _byId.values.where(_canAccessRecord),
      stationId: stationId,
      formType: formType,
      query: query,
      accountKey: _activeAccountKey,
      includeArchived: includeArchived,
    );
  }

  /// Legacy / unassigned quarantine — never mixed into account lists.
  List<LocalCatalogRecord> listUnassigned({bool includeArchived = false}) =>
      LocalCatalogRecordQuery.unassigned(
        records: _byId.values,
        includeArchived: includeArchived,
      );

  /// Explicit operator claim of a quarantined record to [accountKey].
  /// Returns null if missing, already owned by someone else, or account empty.
  LocalCatalogRecord? claimToAccount(String id, String accountKey) {
    final account = accountKey.trim();
    if (account.isEmpty || _activeAccountKey != account) return null;
    final current = _byId[id];
    if (current == null) return null;
    if (current.accountKey != null && current.accountKey!.isNotEmpty) {
      // Already owned — only same account may "claim" (no-op).
      if (current.accountKey != account) return null;
      return current;
    }
    final claimed = LocalCatalogRecord(
      id: current.id,
      stationId: current.stationId,
      formType: current.formType,
      values: current.values,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      status: current.status,
      schemaVersion: current.schemaVersion,
      accountKey: account,
    );
    _byId[id] = claimed;
    _dirtyIds.add(id);
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
    return claimed;
  }

  /// JSON export of the filtered subset (local only).
  String exportJson({
    String? stationId,
    String? formType,
    bool includeArchived = false,
  }) {
    final rows = list(
      stationId: stationId,
      formType: formType,
      includeArchived: includeArchived,
    );
    final envelope = LocalCatalogExportEnvelope(
      exportedAt: DateTime.now().toUtc(),
      records: rows,
    );
    return jsonEncode(envelope.toJson());
  }

  /// Merge import without silent overwrite. Returns counts.
  Map<String, int> importJson(
    String raw, {
    bool overwriteExisting = false,
  }) {
    var added = 0;
    var skipped = 0;
    var updated = 0;
    var corrupt = 0;
    try {
      final decoded = jsonDecode(raw);
      final envelope = LocalCatalogExportEnvelope.tryParse(decoded);
      final records = envelope?.records ??
          (decoded is List
              ? decoded
                  .map(LocalCatalogRecord.tryParse)
                  .whereType<LocalCatalogRecord>()
                  .toList()
              : <LocalCatalogRecord>[]);
      if (envelope == null && decoded is! List) {
        return {'added': 0, 'updated': 0, 'skipped': 0, 'corrupt': 1};
      }
      // Report every malformed row even when other rows import successfully.
      // Previously mixed valid/invalid lists incorrectly reported zero corrupt.
      if (envelope == null && decoded is List) {
        corrupt = decoded.length - records.length;
      } else if (envelope != null && decoded is Map) {
        final rawRecords = decoded['records'];
        if (rawRecords is List) {
          corrupt = rawRecords.length - records.length;
        }
      }
      for (final record in records) {
        // Imported data may only enter the currently authenticated account
        // (or the unassigned quarantine while signed out).
        if (!_canAccessRecord(record)) {
          skipped++;
          continue;
        }
        final existing = _byId[record.id];
        if (existing != null && !_canAccessRecord(existing)) {
          skipped++;
          continue;
        }
        if (existing == null) {
          _byId[record.id] = record;
          _dirtyIds.add(record.id);
          added++;
        } else if (existing.stationId != record.stationId ||
            existing.formType != record.formType) {
          // A stable record id is permanently bound to its station and form.
          // Imports must obey the same identity lock as upsert().
          skipped++;
        } else if (overwriteExisting) {
          _byId[record.id] = LocalCatalogRecord(
            id: record.id,
            stationId: record.stationId,
            formType: record.formType,
            values: record.values,
            createdAt: existing.createdAt,
            updatedAt: DateTime.now().toUtc(),
            status: record.status,
            schemaVersion: record.schemaVersion,
            accountKey: record.accountKey,
          );
          _dirtyIds.add(record.id);
          updated++;
        } else {
          skipped++;
        }
      }
    } catch (_) {
      return {'added': 0, 'updated': 0, 'skipped': 0, 'corrupt': 1};
    }
    if (added > 0 || updated > 0) {
      notifyListeners();
      // ignore: unawaited_futures
      _persist();
    }
    return {
      'added': added,
      'updated': updated,
      'skipped': skipped,
      'corrupt': corrupt,
    };
  }

  /// Test helper: wipe memory (and optionally disk).
  Future<void> clearAll({bool persist = false}) async {
    await ensureLoaded();
    _dirtyIds.addAll(_byId.keys);
    _byId.clear();
    notifyListeners();
    if (persist) {
      await _persist();
    }
  }
}
