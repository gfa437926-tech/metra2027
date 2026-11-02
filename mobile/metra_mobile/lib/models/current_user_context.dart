/// Read-only display context returned by GET /api/v1/identity/me.
///
/// These values must never be treated as proof of authorization. The API must
/// re-evaluate account state, permissions and station scope for every operation.
class CurrentUserContext {
  const CurrentUserContext({
    required this.userId,
    required this.profile,
    required this.accountState,
    required this.assignments,
    required this.permissions,
  });

  final String userId;
  final CurrentUserProfile profile;
  final String accountState;
  final List<CurrentUserStationAssignment> assignments;
  final List<String> permissions;

  factory CurrentUserContext.fromJson(Map<String, dynamic> json) {
    return CurrentUserContext(
      userId: json['userId'] as String,
      profile: CurrentUserProfile.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
      accountState: json['accountState'] as String,
      assignments: (json['assignments'] as List<dynamic>)
          .map((item) => CurrentUserStationAssignment.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(growable: false),
      permissions: (json['permissions'] as List<dynamic>)
          .map((item) => item as String)
          .toList(growable: false),
    );
  }
}

class CurrentUserProfile {
  const CurrentUserProfile({
    required this.firstName,
    required this.fatherName,
    required this.lastName,
    required this.email,
    required this.phone,
  });

  final String firstName;
  final String? fatherName;
  final String lastName;
  final String? email;
  final String? phone;

  factory CurrentUserProfile.fromJson(Map<String, dynamic> json) {
    return CurrentUserProfile(
      firstName: json['firstName'] as String,
      fatherName: json['fatherName'] as String?,
      lastName: json['lastName'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class CurrentUserStationAssignment {
  const CurrentUserStationAssignment({
    required this.stationId,
    required this.stationName,
    required this.roleCode,
    required this.validFrom,
    required this.validTo,
    required this.isActive,
  });

  final String stationId;
  final String stationName;
  final String roleCode;
  final DateTime validFrom;
  final DateTime? validTo;

  /// Server-computed display state, not a grant of access.
  final bool isActive;

  factory CurrentUserStationAssignment.fromJson(Map<String, dynamic> json) {
    return CurrentUserStationAssignment(
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String,
      roleCode: json['roleCode'] as String,
      validFrom: DateTime.parse(json['validFrom'] as String),
      validTo: json['validTo'] == null
          ? null
          : DateTime.parse(json['validTo'] as String),
      isActive: json['isActive'] as bool,
    );
  }
}
