/// Server-authoritative access context for the signed-in user.
///
/// Until an approved access-context API contract exists, this type is always
/// unresolved. It must never invent roles, stations, or permission codes from
/// client claims, local defaults, or hard-coded role matrices.
///
/// See docs/api-contracts/PROPOSED-ACCESS-CONTEXT.md.
class MetraAccessContext {
  const MetraAccessContext._({
    required this.isResolved,
    required this.userId,
    required this.stationPermissions,
  });

  /// No server context available yet — fail closed.
  factory MetraAccessContext.unresolved() => const MetraAccessContext._(
        isResolved: false,
        userId: null,
        stationPermissions: {},
      );

  /// Only for tests or a future real API mapping. Production code must not
  /// call this with fabricated data.
  factory MetraAccessContext.resolved({
    required String userId,
    required Map<String, Set<String>> stationPermissions,
  }) {
    final normalized = <String, Set<String>>{};
    for (final entry in stationPermissions.entries) {
      final stationId = entry.key.trim();
      if (stationId.isEmpty) continue;
      normalized[stationId] = Set<String>.unmodifiable(
        entry.value.where((code) => code.trim().isNotEmpty).toSet(),
      );
    }
    return MetraAccessContext._(
      isResolved: true,
      userId: userId.trim().isEmpty ? null : userId.trim(),
      stationPermissions: Map<String, Set<String>>.unmodifiable(normalized),
    );
  }

  /// True only when populated from an approved server contract.
  final bool isResolved;

  final String? userId;

  /// stationId → permission codes granted on that station.
  final Map<String, Set<String>> stationPermissions;

  /// Fail-closed: returns false when unresolved or station/permission unknown.
  bool hasStationPermission(String stationId, String permissionCode) {
    if (!isResolved) return false;
    final station = stationId.trim();
    final code = permissionCode.trim();
    if (station.isEmpty || code.isEmpty) return false;
    final granted = stationPermissions[station];
    if (granted == null) return false;
    return granted.contains(code);
  }

  /// Whether the user may open station-scoped observation entry for [stationId].
  bool canEnterObservations(String stationId) =>
      hasStationPermission(stationId, 'observation.create') ||
      hasStationPermission(stationId, 'observation.submit');

  /// Whether the user may open the review queue / decisions for [stationId].
  bool canReviewObservations(String stationId) =>
      hasStationPermission(stationId, 'observation.review') ||
      hasStationPermission(stationId, 'observation.approve') ||
      hasStationPermission(stationId, 'observation.return_for_correction');

  /// Whether the user may open station administration for [stationId].
  bool canAdministerStation(String stationId) =>
      hasStationPermission(stationId, 'users.station.view') ||
      hasStationPermission(stationId, 'users.station.manage') ||
      hasStationPermission(stationId, 'registrations.station.approve');
}

/// Shared Arabic copy for permission-denied UI.
class MetraPermissionDeniedMessages {
  const MetraPermissionDeniedMessages._();

  static const general =
      'لا تملك صلاحية الوصول إلى هذه الشاشة. تُفرض الصلاحيات من الخادم.';

  static const observations =
      'لا تملك صلاحية إدخال أو إرسال أرصاد لهذه المحطة.';

  static const review =
      'لا تملك صلاحية مراجعة أرصاد هذه المحطة.';

  static const administration =
      'لا تملك صلاحية إدارة مستخدمي هذه المحطة أو طلبات التسجيل.';

  static const contextUnavailable =
      'سياق الصلاحيات غير متاح من الخادم بعد. ستظهر الشاشات التشغيلية، '
      'ويرفض الخادم أي عملية غير مصرح بها.';
}
