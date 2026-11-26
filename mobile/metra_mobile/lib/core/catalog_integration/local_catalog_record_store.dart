
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_catalog_record.dart';

/// On-device catalogue records (session + SharedPreferences).
///
/// Never syncs to the server. Labels remain "local only".
class LocalCatalogRecordStore extends ChangeNotifier {
  LocalCatalogRecordStore._();

  static final LocalCatalogRecordStore instance = LocalCatalogRecordStore._();

  static const _prefsKey = 'metra2027.local_catalog_records.v1';

  final Map<String, LocalCatalogRecord> _byId = {};
  bool _loaded = false;
  bool _loading = false;

  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  int get count => _byId.length;

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            final record = LocalCatalogRecord.tryParse(item);
            if (record != null) {
              _byId[record.id] = record;
            }
          }
        }
      }
    } catch (_) {
      // Corrupt payload: start empty rather than crashing the operator UI.
      _byId.clear();
    } finally {
      _loaded = true;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = _byId.values.map((r) => r.toJson()).toList(growable: false);
      await prefs.setString(_prefsKey, jsonEncode(payload));
    } catch (_) {
      // Persistence failure must not discard in-memory records this session.
    }
  }

  LocalCatalogRecord upsert({
    String? id,
    required String stationId,
    required String formType,
    required Map<String, Object?> values,
  }) {
    final now = DateTime.now().toUtc();
    final station = stationId.trim();
    final type = formType.trim().toLowerCase();
    if (station.isEmpty || type.isEmpty) {
      throw ArgumentError('stationId and formType are required');
    }
    final recordId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : 'local-${type}-${now.microsecondsSinceEpoch}';
    final existing = _byId[recordId];
    final next = LocalCatalogRecord(
      id: recordId,
      stationId: station,
      formType: type,
      values: Map.unmodifiable(Map<String, Object?>.from(values)),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: LocalCatalogRecordStatus.localSaved,
    );
    _byId[recordId] = next;
    notifyListeners();
    // Fire-and-forget disk write.
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
    bool includeArchived = false,
  }) =>
      LocalCatalogRecordQuery.filter(
        records: _byId.values,
        stationId: stationId,
        formType: formType,
        query: query,
        includeArchived: includeArchived,
      );

  /// Test helper: wipe memory (and optionally disk).
  Future<void> clearAll({bool persist = false}) async {
    _byId.clear();
    notifyListeners();
    if (persist) {
      await _persist();
    }
  }
}
