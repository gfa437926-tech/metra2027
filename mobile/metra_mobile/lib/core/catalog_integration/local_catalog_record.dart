/// One locally persisted catalogue observation/fault record.
///
/// Never claims server sync. [status] is always a local lifecycle value.
class LocalCatalogRecord {
  const LocalCatalogRecord({
    required this.id,
    required this.stationId,
    required this.formType,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
    this.status = LocalCatalogRecordStatus.localSaved,
    this.schemaVersion = currentSchemaVersion,
    this.accountKey,
  });

  /// Bump only when on-disk shape changes incompatibly.
  static const int currentSchemaVersion = 1;

  final String id;
  final String stationId;
  final String formType;
  final Map<String, Object?> values;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LocalCatalogRecordStatus status;
  final int schemaVersion;

  /// Optional opaque account scope (e.g. auth user id). Null = device-wide.
  final String? accountKey;

  LocalCatalogRecord copyWith({
    Map<String, Object?>? values,
    DateTime? updatedAt,
    LocalCatalogRecordStatus? status,
    String? accountKey,
    bool clearAccountKey = false,
  }) =>
      LocalCatalogRecord(
        id: id,
        stationId: stationId,
        formType: formType,
        values: values ?? this.values,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        status: status ?? this.status,
        schemaVersion: schemaVersion,
        accountKey: clearAccountKey ? null : (accountKey ?? this.accountKey),
      );

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'stationId': stationId,
        'formType': formType,
        'values': values,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'status': status.name,
        if (accountKey != null && accountKey!.isNotEmpty) 'accountKey': accountKey,
      };

  /// Returns null for unrecoverable rows; never throws.
  static LocalCatalogRecord? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = map['id']?.toString().trim();
    final stationId = map['stationId']?.toString().trim();
    final formType = map['formType']?.toString().trim().toLowerCase();
    final createdAt = DateTime.tryParse('${map['createdAt'] ?? ''}');
    final updatedAt = DateTime.tryParse('${map['updatedAt'] ?? ''}');
    if (id == null ||
        id.isEmpty ||
        stationId == null ||
        stationId.isEmpty ||
        formType == null ||
        formType.isEmpty ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }
    final valuesRaw = map['values'];
    final values = <String, Object?>{};
    if (valuesRaw is Map) {
      valuesRaw.forEach((key, value) {
        final k = '$key'.trim();
        if (k.isEmpty) return;
        values[k] = value;
      });
    }
    final statusName = map['status']?.toString() ?? 'localSaved';
    final status = LocalCatalogRecordStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => LocalCatalogRecordStatus.localSaved,
    );
    final schemaRaw = map['schemaVersion'];
    final schemaVersion = schemaRaw is int
        ? schemaRaw
        : int.tryParse('${schemaRaw ?? ''}') ?? currentSchemaVersion;
    final accountKey = map['accountKey']?.toString().trim();
    return LocalCatalogRecord(
      id: id,
      stationId: stationId,
      formType: formType,
      values: Map.unmodifiable(values),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      status: status,
      schemaVersion: schemaVersion <= 0 ? currentSchemaVersion : schemaVersion,
      accountKey: (accountKey == null || accountKey.isEmpty) ? null : accountKey,
    );
  }
}

enum LocalCatalogRecordStatus {
  /// Accepted and stored only on-device.
  localSaved,

  /// Explicitly marked by the operator as discarded/archived locally.
  localArchived,
}

/// Pure helpers for filtering/sorting local catalogue records.
class LocalCatalogRecordQuery {
  LocalCatalogRecordQuery._();

  static List<LocalCatalogRecord> filter({
    required Iterable<LocalCatalogRecord> records,
    String? stationId,
    String? formType,
    String? query,
    String? accountKey,
    bool includeArchived = false,
  }) {
    final q = query?.trim().toLowerCase() ?? '';
    final station = stationId?.trim() ?? '';
    final type = formType?.trim().toLowerCase() ?? '';
    final account = accountKey?.trim() ?? '';
    final list = records.where((r) {
      if (!includeArchived &&
          r.status == LocalCatalogRecordStatus.localArchived) {
        return false;
      }
      if (station.isNotEmpty && r.stationId != station) return false;
      if (type.isNotEmpty && r.formType != type) return false;
      if (account.isNotEmpty) {
        // Records without accountKey are legacy device-wide; keep visible.
        if (r.accountKey != null && r.accountKey != account) return false;
      }
      if (q.isEmpty) return true;
      if (r.id.toLowerCase().contains(q)) return true;
      if (r.formType.contains(q)) return true;
      for (final entry in r.values.entries) {
        final text = entry.value?.toString().toLowerCase() ?? '';
        if (text.contains(q)) return true;
      }
      return false;
    }).toList(growable: false);
    final sorted = List<LocalCatalogRecord>.of(list)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(sorted);
  }
}

/// Envelope for local export/import (never a server payload).
class LocalCatalogExportEnvelope {
  const LocalCatalogExportEnvelope({
    required this.exportedAt,
    required this.records,
    this.schemaVersion = LocalCatalogRecord.currentSchemaVersion,
  });

  final DateTime exportedAt;
  final List<LocalCatalogRecord> records;
  final int schemaVersion;

  Map<String, Object?> toJson() => {
        'kind': 'metra2027.local_catalog_export',
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'recordCount': records.length,
        'records': records.map((r) => r.toJson()).toList(growable: false),
      };

  static LocalCatalogExportEnvelope? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map['kind']?.toString() != 'metra2027.local_catalog_export') {
      return null;
    }
    final exportedAt = DateTime.tryParse('${map['exportedAt'] ?? ''}');
    final listRaw = map['records'];
    if (exportedAt == null || listRaw is! List) return null;
    final records = <LocalCatalogRecord>[];
    for (final item in listRaw) {
      final parsed = LocalCatalogRecord.tryParse(item);
      if (parsed != null) records.add(parsed);
    }
    final schemaRaw = map['schemaVersion'];
    final schemaVersion = schemaRaw is int
        ? schemaRaw
        : int.tryParse('${schemaRaw ?? ''}') ??
            LocalCatalogRecord.currentSchemaVersion;
    return LocalCatalogExportEnvelope(
      exportedAt: exportedAt.toUtc(),
      records: List.unmodifiable(records),
      schemaVersion: schemaVersion,
    );
  }
}
