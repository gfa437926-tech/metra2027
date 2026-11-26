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

  static final LocalCatalogRecordStore instance = LocalCatalogRecordStore._();

  static const _prefsKey = 'metra2027.local_catalog_records.v1';
  static const _prefsMetaKey = 'metra2027.local_catalog_records.meta.v1';

  final Map<String, LocalCatalogRecord> _byId = {};
  bool _loaded = false;
  bool _loading = false;
  int _lastSkippedCorrupt = 0;
  String? _activeAccountKey;
  String? lastPersistError;

  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  int get count => _byId.length;
  int get lastSkippedCorrupt => _lastSkippedCorrupt;

  /// Optional account scope applied to new writes (auth user id).
  void setActiveAccountKey(String? key) {
    final next = key?.trim();
    _activeAccountKey = (next == null || next.isEmpty) ? null : next;
  }

  String? get activeAccountKey => _activeAccountKey;

  Future<LocalCatalogLoadReport> ensureLoaded() async {
    if (_loaded) {
      return LocalCatalogLoadReport(
        loaded: _byId.length,
        skippedCorrupt: _lastSkippedCorrupt,
      );
    }
    if (_loading) {
      // Wait-free: concurrent callers see eventual notifyListeners.
      return const LocalCatalogLoadReport(loaded: 0, skippedCorrupt: 0);
    }
    _loading = true;
    var skipped = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        Object? decoded;
        try {
          decoded = jsonDecode(raw);
        } catch (_) {
          // Keep empty map; do not wipe disk until a successful rewrite.
          skipped = 1;
          decoded = null;
        }
        if (decoded is List) {
          for (final item in decoded) {
            final record = LocalCatalogRecord.tryParse(item);
            if (record == null) {
              skipped++;
              continue;
            }
            // Prefer newer updatedAt when duplicate ids appear in payload.
            final existing = _byId[record.id];
            if (existing == null ||
                record.updatedAt.isAfter(existing.updatedAt)) {
              _byId[record.id] = record;
            }
          }
        } else if (decoded is Map) {
          // Legacy single-object mistake: attempt one record recovery.
          final record = LocalCatalogRecord.tryParse(decoded);
          if (record != null) {
            _byId[record.id] = record;
          } else {
            skipped++;
          }
        }
      }
    } catch (_) {
      // Unexpected I/O: leave memory as-is for this session.
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

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload =
          _byId.values.map((r) => r.toJson()).toList(growable: false);
      await prefs.setString(_prefsKey, jsonEncode(payload));
      await prefs.setString(
        _prefsMetaKey,
        jsonEncode({
          'schemaVersion': LocalCatalogRecord.currentSchemaVersion,
          'count': payload.length,
          'writtenAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      if (lastPersistError != null) {
        lastPersistError = null;
        notifyListeners();
      }
    } catch (error) {
      // Persistence failure must not discard in-memory records this session.
      lastPersistError =
          'تعذر حفظ السجلات المحلية على الجهاز. تبقى متاحة لهذه الجلسة فقط.';
      notifyListeners();
    }
  }

  /// Create or update by stable [id]. Empty id creates a new record.
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
    final recordId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : 'local-$type-${now.microsecondsSinceEpoch}';
    final existing = _byId[recordId];
    // Identity lock: cannot change station/formType of an existing id.
    if (existing != null) {
      if (existing.stationId != station || existing.formType != type) {
        throw StateError(
          'cannot reassign station/formType for existing local record $recordId',
        );
      }
    }
    final resolvedAccount =
        accountKey?.trim().isNotEmpty == true
            ? accountKey!.trim()
            : (existing?.accountKey ?? _activeAccountKey);
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
    notifyListeners();
    // ignore: unawaited_futures
    _persist();
    return next;
  }

  bool archive(String id) {
    final current = _byId[id];
    if (current == null) return false;
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
    if (current == null) return false;
    if (current.status != LocalCatalogRecordStatus.localArchived) {
      return false;
    }
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
    final removed = _byId.remove(id) != null;
    if (removed) {
      notifyListeners();
      // ignore: unawaited_futures
      _persist();
    }
    return removed;
  }

  LocalCatalogRecord? getById(String id) => _byId[id];

  List<LocalCatalogRecord> list({
    String? stationId,
    String? formType,
    String? query,
    String? accountKey,
    bool includeArchived = false,
  }) =>
      LocalCatalogRecordQuery.filter(
        records: _byId.values,
        stationId: stationId,
        formType: formType,
        query: query,
        accountKey: accountKey ?? _activeAccountKey,
        includeArchived: includeArchived,
      );

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
      for (final record in records) {
        final existing = _byId[record.id];
        if (existing == null) {
          _byId[record.id] = record;
          added++;
        } else if (overwriteExisting) {
          _byId[record.id] = record.copyWith(updatedAt: DateTime.now().toUtc());
          updated++;
        } else {
          skipped++;
        }
      }
      if (records.isEmpty && decoded is List) {
        // Count unparseable list items as corrupt.
        corrupt = decoded.length;
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
    _byId.clear();
    notifyListeners();
    if (persist) {
      await _persist();
    }
  }
}
