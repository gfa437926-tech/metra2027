/// Server-authoritative access context for the signed-in user.
///
/// Production data must come only from GET /api/v1/me/access-context.
/// Never invent roles, stations, or permission codes from client claims.
///
/// See docs/api-contracts/PROPOSED-ACCESS-CONTEXT.md.
class MetraAccessContext {
  const MetraAccessContext._({
    required this.isResolved,
    required this.userId,
    required this.accountState,
    required this.stationPermissions,
    required this.stationRoles,
  });

  /// No server context available yet — fail closed.
  factory MetraAccessContext.unresolved() => const MetraAccessContext._(
        isResolved: false,
        userId: null,
        accountState: null,
        stationPermissions: {},
        stationRoles: {},
      );

  /// Built only from a successful access-context API response (or unit fixtures).
  factory MetraAccessContext.resolved({
    required String userId,
    String? accountState,
    required Map<String, Set<String>> stationPermissions,
    Map<String, String> stationRoles = const {},
  }) {
    final normalized = <String, Set<String>>{};
    for (final entry in stationPermissions.entries) {
      final stationId = entry.key.trim();
      if (stationId.isEmpty) continue;
      normalized[stationId] = Set<String>.unmodifiable(
        entry.value.where((code) => code.trim().isNotEmpty).toSet(),
      );
    }
    final roles = <String, String>{};
    for (final entry in stationRoles.entries) {
      final stationId = entry.key.trim();
      final role = entry.value.trim();
      if (stationId.isEmpty || role.isEmpty) continue;
      roles[stationId] = role;
    }
    return MetraAccessContext._(
      isResolved: true,
      userId: userId.trim().isEmpty ? null : userId.trim(),
      accountState: accountState?.trim().isEmpty == true
          ? null
          : accountState?.trim(),
      stationPermissions: Map<String, Set<String>>.unmodifiable(normalized),
      stationRoles: Map<String, String>.unmodifiable(roles),
    );
  }

  /// True only when populated from the server contract.
  final bool isResolved;

  final String? userId;
  final String? accountState;

  /// stationId → permission codes granted on that station.
  final Map<String, Set<String>> stationPermissions;

  /// stationId → assignment role_code when returned by the server.
  final Map<String, String> stationRoles;

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

  bool canEnterObservations(String stationId) =>
      hasStationPermission(stationId, 'observation.create') ||
      hasStationPermission(stationId, 'observation.submit');

  bool canReviewObservations(String stationId) =>
      hasStationPermission(stationId, 'observation.review') ||
      hasStationPermission(stationId, 'observation.approve') ||
      hasStationPermission(stationId, 'observation.return_for_correction');

  bool canAdministerStation(String stationId) =>
      hasStationPermission(stationId, 'users.station.view') ||
      hasStationPermission(stationId, 'users.station.manage') ||
      hasStationPermission(stationId, 'registrations.station.approve');

  /// Any station where observation entry is allowed.
  bool get canAccessAnyObservationWorkspace {
    if (!isResolved) return false;
    for (final stationId in stationPermissions.keys) {
      if (canEnterObservations(stationId) || canReviewObservations(stationId)) {
        return true;
      }
    }
    return false;
  }

  /// Any station where administration is allowed.
  bool get canAccessAnyStationAdministration {
    if (!isResolved) return false;
    for (final stationId in stationPermissions.keys) {
      if (canAdministerStation(stationId)) return true;
    }
    return false;
  }
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
      'تعذر تحميل سياق الصلاحيات من الخادم. لا تُعرض الشاشات التشغيلية '
      'حتى يتوفر سياق موثوق.';

  static const contextLoading = 'جارٍ تحميل صلاحيات الحساب…';
}
