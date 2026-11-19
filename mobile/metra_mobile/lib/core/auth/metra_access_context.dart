/// Server-authoritative access context for the signed-in user.
///
/// Production data must come only from GET /api/v1/me/access-context.
/// Never invent roles, stations, or permission codes from client claims.
class MetraAccessContext {
  const MetraAccessContext._({
    required this.isResolved,
    required this.userId,
    required this.accountState,
    required this.stationPermissions,
    required this.stationRoles,
  });

  factory MetraAccessContext.unresolved() => const MetraAccessContext._(
        isResolved: false,
        userId: null,
        accountState: null,
        stationPermissions: {},
        stationRoles: {},
      );

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

  final bool isResolved;
  final String? userId;
  final String? accountState;
  final Map<String, Set<String>> stationPermissions;
  final Map<String, String> stationRoles;

  /// accountState is informational only; never treat "unknown" as active.
  bool get hasKnownActiveAccount =>
      isResolved && accountState != null && accountState == 'active';

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
      hasStationPermission(stationId, 'observation.submit') ||
      hasStationPermission(stationId, 'observation.edit_own_draft');

  bool canReviewObservations(String stationId) =>
      hasStationPermission(stationId, 'observation.review') ||
      hasStationPermission(stationId, 'observation.approve') ||
      hasStationPermission(stationId, 'observation.return_for_correction');

  bool canAdministerStation(String stationId) =>
      hasStationPermission(stationId, 'users.station.view') ||
      hasStationPermission(stationId, 'users.station.manage') ||
      hasStationPermission(stationId, 'registrations.station.approve');

  bool canAccessObservationWorkspace(String stationId) =>
      canEnterObservations(stationId) || canReviewObservations(stationId);

  bool get canAccessAnyObservationWorkspace {
    if (!isResolved) return false;
    for (final stationId in stationPermissions.keys) {
      if (canAccessObservationWorkspace(stationId)) return true;
    }
    return false;
  }

  bool get canAccessAnyStationAdministration {
    if (!isResolved) return false;
    for (final stationId in stationPermissions.keys) {
      if (canAdministerStation(stationId)) return true;
    }
    return false;
  }

  /// Destination visibility from permission codes only (no role names).
  ///
  /// - Always for signed-in users: home, stations, settings
  /// - Placeholders without backend contracts stay visible (informational only)
  /// - observations / admin require at least one station with matching codes
  /// - When context is unresolved: operational destinations are hidden (fail-closed)
  bool isDestinationVisible(MetraDestinationId id) {
    switch (id) {
      case MetraDestinationId.home:
      case MetraDestinationId.stations:
      case MetraDestinationId.settings:
        return true;
      case MetraDestinationId.forecast:
      case MetraDestinationId.climatol:
      case MetraDestinationId.recordsAi:
      case MetraDestinationId.operations:
      case MetraDestinationId.reports:
        // No permission codes exist yet; screens show explicit offline notices.
        return true;
      case MetraDestinationId.observations:
        return canAccessAnyObservationWorkspace;
      case MetraDestinationId.admin:
        return canAccessAnyStationAdministration;
    }
  }
}

enum MetraDestinationId {
  home,
  stations,
  forecast,
  observations,
  climatol,
  recordsAi,
  operations,
  reports,
  admin,
  settings,
}

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

  static const destinationHidden =
      'هذه الوجهة غير متاحة لحسابك حسب صلاحيات الخادم.';
}
