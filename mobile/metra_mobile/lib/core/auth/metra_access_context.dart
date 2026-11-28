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
    required this.authorityPermissions,
    required this.authorityRoles,
  });

  factory MetraAccessContext.unresolved() => const MetraAccessContext._(
    isResolved: false,
    userId: null,
    accountState: null,
    stationPermissions: {},
    stationRoles: {},
    authorityPermissions: {},
    authorityRoles: {},
  );

  factory MetraAccessContext.resolved({
    required String userId,
    String? accountState,
    required Map<String, Set<String>> stationPermissions,
    Map<String, String> stationRoles = const {},
    Map<String, Set<String>> authorityPermissions = const {},
    Map<String, String> authorityRoles = const {},
  }) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be blank');
    }
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
    final normalizedAuthorityPermissions = <String, Set<String>>{};
    for (final entry in authorityPermissions.entries) {
      final id = entry.key.trim();
      if (id.isEmpty) continue;
      normalizedAuthorityPermissions[id] = Set<String>.unmodifiable(
        entry.value.where((code) => code.trim().isNotEmpty).toSet(),
      );
    }
    final normalizedAuthorityRoles = <String, String>{};
    for (final entry in authorityRoles.entries) {
      final id = entry.key.trim();
      final role = entry.value.trim();
      if (id.isNotEmpty && role.isNotEmpty) normalizedAuthorityRoles[id] = role;
    }
    return MetraAccessContext._(
      isResolved: true,
      userId: userId.trim().isEmpty ? null : userId.trim(),
      accountState: accountState?.trim().isEmpty == true
          ? null
          : accountState?.trim(),
      stationPermissions: Map<String, Set<String>>.unmodifiable(normalized),
      stationRoles: Map<String, String>.unmodifiable(roles),
      authorityPermissions: Map<String, Set<String>>.unmodifiable(normalizedAuthorityPermissions),
      authorityRoles: Map<String, String>.unmodifiable(normalizedAuthorityRoles),
    );
  }

  final bool isResolved;
  final String? userId;
  final String? accountState;
  final Map<String, Set<String>> stationPermissions;
  final Map<String, String> stationRoles;
  final Map<String, Set<String>> authorityPermissions;
  final Map<String, String> authorityRoles;

  bool hasAuthorityPermission(String authorityId, String permissionCode) {
    if (!isResolved || !hasKnownActiveAccount) return false;
    final id = authorityId.trim();
    final code = permissionCode.trim();
    if (id.isEmpty || code.isEmpty) return false;
    return authorityPermissions[id]?.contains(code) ?? false;
  }

  /// Only an explicit server-reported active account is treated as operational.
  /// unknown / inactive / null never unlock observations, review, or admin.
  bool get hasKnownActiveAccount =>
      isResolved && accountState != null && accountState == 'active';

  bool hasStationPermission(String stationId, String permissionCode) {
    if (!isResolved || !hasKnownActiveAccount) return false;
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
    if (!isResolved || !hasKnownActiveAccount) return false;
    for (final stationId in stationPermissions.keys) {
      if (canAccessObservationWorkspace(stationId)) return true;
    }
    return false;
  }

  bool get canAccessAnyStationAdministration {
    if (!isResolved || !hasKnownActiveAccount) return false;
    for (final stationId in stationPermissions.keys) {
      if (canAdministerStation(stationId)) return true;
    }
    return false;
  }

  /// Destination visibility from permission codes + known-active account.
  ///
  /// - Always for signed-in users: home, stations, settings
  /// - Placeholders without backend contracts stay visible (informational only)
  /// - observations / admin require at least one station with matching codes
  ///   and a known-active account (fail-closed for unknown/inactive)
  /// - When context is unresolved: operational destinations are hidden
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

  static const review = 'لا تملك صلاحية مراجعة أرصاد هذه المحطة.';

  static const administration =
      'لا تملك صلاحية إدارة مستخدمي هذه المحطة أو طلبات التسجيل.';

  static const contextUnavailable =
      'تعذر تحميل سياق الصلاحيات من الخادم. لا تُعرض الشاشات التشغيلية '
      'حتى يتوفر سياق موثوق.';

  static const contextLoading = 'جارٍ تحميل صلاحيات الحساب…';

  static const destinationHidden =
      'هذه الوجهة غير متاحة لحسابك حسب صلاحيات الخادم.';

  static const accountNotActive =
      'حسابك غير نشط أو حالته غير معروفة. لا تُمنح صلاحيات تشغيلية حتى يصبح الحساب نشطاً على الخادم.';
}
