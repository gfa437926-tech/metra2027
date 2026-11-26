
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
  });

  final String id;
  final String stationId;
  final String formType;
  final Map<String, Object?> values;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LocalCatalogRecordStatus status;

  LocalCatalogRecord copyWith({
    Map<String, Object?>? values,
    DateTime? updatedAt,
    LocalCatalogRecordStatus? status,
  }) =>
      LocalCatalogRecord(
        id: id,
        stationId: stationId,
        formType: formType,
        values: values ?? this.values,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        status: status ?? this.status,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'stationId': stationId,
        'formType': formType,
        'values': values,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'status': status.name,
      };

  static LocalCatalogRecord? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = map['id']?.toString();
    final stationId = map['stationId']?.toString();
    final formType = map['formType']?.toString();
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
        values['$key'] = value;
      });
    }
    final statusName = map['status']?.toString() ?? 'localSaved';
    final status = LocalCatalogRecordStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => LocalCatalogRecordStatus.localSaved,
    );
    return LocalCatalogRecord(
      id: id,
      stationId: stationId,
      formType: formType.toLowerCase(),
      values: Map.unmodifiable(values),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      status: status,
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
    bool includeArchived = false,
  }) {
    final q = query?.trim().toLowerCase() ?? '';
    final station = stationId?.trim() ?? '';
    final type = formType?.trim().toLowerCase() ?? '';
    final list = records.where((r) {
      if (!includeArchived && r.status == LocalCatalogRecordStatus.localArchived) {
        return false;
      }
      if (station.isNotEmpty && r.stationId != station) return false;
      if (type.isNotEmpty && r.formType != type) return false;
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
