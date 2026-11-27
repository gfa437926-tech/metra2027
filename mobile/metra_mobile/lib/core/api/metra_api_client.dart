import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../api_config.dart';
import '../auth/metra_access_context.dart';

const metraApiBaseUrl = ApiConfig.baseUrl;

class MetraApiException implements Exception {
  const MetraApiException(this.statusCode, this.code, {this.userMessage});
  final int statusCode;
  final String code;
  final String? userMessage;

  String get displayMessage {
    if (userMessage != null && userMessage!.trim().isNotEmpty) {
      return userMessage!.trim();
    }
    return switch (code) {
      'api_not_configured' =>
        'عنوان خدمة METRA غير مضبوط. راجع إعدادات الاتصال.',
      'authentication_required' => 'انتهت الجلسة أو يلزم تسجيل الدخول مجدداً.',
      'invalid_pagination' => 'معاملات التصفح غير صالحة.',
      'invalid_station_type' => 'نوع المحطة غير مدعوم.',
      'invalid_station_id' => 'معرف المحطة غير صالح.',
      'invalid_observation_id' => 'معرف الرصدة غير صالح.',
      'invalid_limit' => 'حد النتائج غير صالح.',
      'invalid_observation_decision' => 'قرار المراجعة غير مدعوم.',
      'decision_note_required' => 'يجب إدخال سبب الإرجاع للتصحيح.',
      'invalid_decision_note' => 'نص الملاحظة غير صالح.',
      'invalid_registration_decision' => 'قرار التسجيل غير مدعوم.',
      'registration_rejection_reason_required' =>
        'يجب إدخال سبب رفض طلب التسجيل.',
      'invalid_registration_note' => 'نص ملاحظة التسجيل غير صالح.',
      'unsupported_observation_validation' =>
        'نوع الرصد غير مدعوم للتحقق حالياً.',
      'unsupported_observation_type' => 'نوع الرصد غير مدعوم للإرسال حالياً.',
      'invalid_idempotency_key' => 'مفتاح منع التكرار غير صالح.',
      'station_directory_limit_exceeded' =>
        'تجاوز دليل المحطات الحد الأقصى المسموح.',
      'network_unavailable' =>
        'تعذر الاتصال بالخادم. تحقق من الشبكة ثم أعد المحاولة.',
      'timeout' => 'انتهت مهلة الاتصال بالخادم. أعد المحاولة لاحقاً.',
      'request_failed' when statusCode == 401 || statusCode == 403 =>
        'انتهت صلاحية الجلسة أو لا تملك صلاحية تنفيذ هذه العملية.',
      'request_failed' when statusCode == 404 => 'المورد المطلوب غير موجود.',
      'request_failed' when statusCode == 409 =>
        'تعارض في الطلب. قد تكون الرصدة مُرسلة مسبقاً.',
      'request_failed' when statusCode >= 500 =>
        'حدث خطأ في الخادم. حاول لاحقاً أو أبلغ الدعم.',
      'request_failed' => 'تعذر إتمام الطلب. تحقق من الاتصال وأعد المحاولة.',
      _ => 'تعذر إتمام العملية. أعد المحاولة أو تواصل مع الدعم.',
    };
  }

  @override
  String toString() => 'MetraApiException($statusCode, $code)';
}

class MetraValidationIssue {
  const MetraValidationIssue({required this.field, required this.message});
  final String field;
  final String message;
}

class MetraObservationValidation {
  const MetraObservationValidation({
    required this.isValid,
    required this.issues,
  });
  final bool isValid;
  final List<MetraValidationIssue> issues;
}

class ObservationQueueItem {
  const ObservationQueueItem({
    required this.id,
    required this.stationId,
    required this.observationType,
    required this.observedAt,
    required this.status,
    this.payload = const {},
  });
  final String id;
  final String stationId;
  final String observationType;
  final DateTime observedAt;
  final String status;
  final Map<String, dynamic> payload;

  factory ObservationQueueItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final stationId = json['station_id'] ?? json['stationId'];
    final type = json['observation_type'] ?? json['observationType'];
    final observedAtRaw = json['observed_at'] ?? json['observedAt'] ?? '';
    final observedAt = DateTime.tryParse('$observedAtRaw');
    if (id is! String ||
        id.trim().isEmpty ||
        stationId is! String ||
        stationId.trim().isEmpty ||
        type is! String ||
        type.trim().isEmpty ||
        observedAtRaw is! String ||
        observedAtRaw.trim().isEmpty ||
        observedAt == null) {
      throw const FormatException('invalid_observation_queue_item');
    }
    final status = json['status'];
    final rawPayload = json['payload'];
    if (status != 'submitted' ||
        (rawPayload != null &&
            (rawPayload is! Map || rawPayload.keys.any((key) => key is! String)))) {
      throw const FormatException('invalid_observation_queue_item');
    }
    return ObservationQueueItem(
      id: id,
      stationId: stationId,
      observationType: type,
      observedAt: observedAt,
      status: status as String,
      payload: rawPayload == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(rawPayload as Map),
    );
  }
}

class StationDirectoryItem {
  const StationDirectoryItem({
    required this.id,
    required this.localCode,
    required this.nameArabic,
    required this.nameEnglish,
    required this.stationType,
    required this.operationalStatus,
    required this.approvalStatus,
    required this.isDemo,
    this.latitude,
    this.longitude,
    this.wmoStationId,
    this.elevationM,
    this.coordinateSource,
    this.coordinateAccuracyM,
  });
  final String id, localCode, nameArabic, nameEnglish, stationType;
  final String operationalStatus, approvalStatus;
  final bool isDemo;
  final double? latitude, longitude;
  final String? wmoStationId;
  final double? elevationM;
  final String? coordinateSource;
  final double? coordinateAccuracyM;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasValidCoordinates =>
      hasCoordinates &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;
  factory StationDirectoryItem.fromJson(Map<String, dynamic> json) {
    for (final key in [
      'id',
      'local_station_code',
      'name_ar',
      'name_en',
      'station_type',
      'operational_status',
      'approval_status',
    ]) {
      if (json[key] is! String) {
        throw const FormatException('invalid_station_directory_item');
      }
    }
    double? number(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('$value');
    double? lat, lon;
    Map<String, dynamic>? point;
    final coords = json['station_coordinates'];
    if (coords is List && coords.isNotEmpty && coords.first is Map) {
      point = Map<String, dynamic>.from(coords.first as Map);
      lat = number(point['latitude']);
      lon = number(point['longitude']);
    }
    return StationDirectoryItem(
      id: json['id'] as String,
      localCode: json['local_station_code'] as String,
      nameArabic: json['name_ar'] as String,
      nameEnglish: json['name_en'] as String,
      stationType: json['station_type'] as String,
      operationalStatus: json['operational_status'] as String,
      approvalStatus: json['approval_status'] as String,
      isDemo: json['is_demo'] == true,
      latitude: lat,
      longitude: lon,
      wmoStationId: json['wmo_station_id'] as String?,
      elevationM: number(json['elevation_m']),
      coordinateSource: point?['coordinate_source'] is String
          ? point!['coordinate_source'] as String
          : null,
      coordinateAccuracyM: point == null ? null : number(point['accuracy_m']),
    );
  }
}

/// API wrapper. Supply a current Supabase access token from the auth layer.
/// Time contract: observation timestamps are sent as UTC ISO-8601.
class MetraApiClient {
  MetraApiClient({
    required this.accessTokenProvider,
    String baseUrl = metraApiBaseUrl,
    http.Client? client,
    Duration requestTimeout = const Duration(seconds: 30),
  }) : _baseUri = Uri.tryParse(baseUrl.trim()),
       _client = client ?? http.Client(),
       _requestTimeout = requestTimeout <= Duration.zero
           ? const Duration(seconds: 30)
           : requestTimeout;

  final Future<String?> Function() accessTokenProvider;
  final Uri? _baseUri;
  final http.Client _client;
  final Duration _requestTimeout;
  bool get isConfigured => ApiConfig.isValidUrl(_baseUri?.toString() ?? '');

  Future<List<StationDirectoryItem>> getStationDirectory({
    int limit = 250,
    int offset = 0,
    String? stationType,
  }) async {
    if (limit < 1 || limit > 500 || offset < 0) {
      throw const MetraApiException(400, 'invalid_pagination');
    }
    if (stationType != null &&
        !const {'classic', 'automatic', 'synoptic'}.contains(stationType)) {
      throw const MetraApiException(400, 'invalid_station_type');
    }
    final filter = stationType == null ? '' : '&stationType=$stationType';
    final response = await _send(
      'GET',
      '/api/v1/stations?limit=$limit&offset=$offset$filter',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('invalid_station_directory');
    }
    return decoded
        .map(
          (item) => StationDirectoryItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<StationDirectoryItem>> getAllStationDirectory({
    String? stationType,
  }) async {
    const pageSize = 500;
    const maximumRows = 10000;
    final stations = <StationDirectoryItem>[];
    for (var offset = 0; offset < maximumRows; offset += pageSize) {
      final page = await getStationDirectory(
        limit: pageSize,
        offset: offset,
        stationType: stationType,
      );
      stations.addAll(page);
      if (page.length < pageSize) return stations;
    }

    // The cap itself is not proof that more rows exist. Probe one row beyond
    // the cap so an exact 10,000-row directory is accepted while larger
    // directories still fail explicitly rather than being silently truncated.
    final overflowProbe = await getStationDirectory(
      limit: 1,
      offset: maximumRows,
      stationType: stationType,
    );
    if (overflowProbe.isEmpty) return stations;
    throw const MetraApiException(413, 'station_directory_limit_exceeded');
  }

  Future<List<ObservationQueueItem>> getReviewQueue(
    String stationId, {
    int limit = 50,
  }) async {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    if (limit < 1 || limit > 100) {
      throw const MetraApiException(400, 'invalid_limit');
    }
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations?limit=$limit',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('invalid_observation_queue');
    }
    return decoded
        .map(
          (item) => ObservationQueueItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> decideObservation({
    required String stationId,
    required String observationId,
    required String decision,
    String? note,
  }) async {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    _requirePathIdentifier(observationId, 'invalid_observation_id');
    if (decision != 'approve' && decision != 'return_for_correction') {
      throw const MetraApiException(400, 'invalid_observation_decision');
    }
    if (decision == 'return_for_correction' &&
        (note == null || note.trim().isEmpty)) {
      throw const MetraApiException(400, 'decision_note_required');
    }
    if (note != null && (note.length > 2000 || note != note.trim())) {
      throw const MetraApiException(400, 'invalid_decision_note');
    }
    await _send(
      'POST',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations/${Uri.encodeComponent(observationId)}/decision',
      body: {
        'decision': decision,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getStationUsers(
    String stationId, {
    int limit = 250,
  }) {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    if (limit < 1 || limit > 500) {
      throw const MetraApiException(400, 'invalid_limit');
    }
    final path = <String>[
      '/api/v1/stations/',
      Uri.encodeComponent(stationId),
      '/users?limit=',
      limit.toString(),
    ].join();
    return _getJsonRecords(path, 'invalid_station_user_directory');
  }

  Future<List<Map<String, dynamic>>> getStationRegistrationRequests(
    String stationId, {
    int limit = 50,
  }) {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    if (limit < 1 || limit > 100) {
      throw const MetraApiException(400, 'invalid_limit');
    }
    final path = <String>[
      '/api/v1/stations/',
      Uri.encodeComponent(stationId),
      '/registration-requests?limit=',
      limit.toString(),
    ].join();
    return _getJsonRecords(path, 'invalid_station_registration_queue');
  }

  Future<List<Map<String, dynamic>>> getStationAuditLog(
    String stationId, {
    int limit = 100,
  }) {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    if (limit < 1 || limit > 250) {
      throw const MetraApiException(400, 'invalid_limit');
    }
    final path = <String>[
      '/api/v1/stations/',
      Uri.encodeComponent(stationId),
      '/audit-log?limit=',
      limit.toString(),
    ].join();
    return _getJsonRecords(path, 'invalid_station_audit_log');
  }

  Future<void> decideStationRegistrationRequest({
    required String stationId,
    required String requestId,
    required String decision,
    String? note,
  }) async {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    _requirePathIdentifier(requestId, 'invalid_registration_request_id');
    if (decision != 'approve' && decision != 'reject') {
      throw const MetraApiException(400, 'invalid_registration_decision');
    }
    if (decision == 'reject' && (note == null || note.trim().isEmpty)) {
      throw const MetraApiException(
        400,
        'registration_rejection_reason_required',
      );
    }
    if (note != null && (note.length > 2000 || note != note.trim())) {
      throw const MetraApiException(400, 'invalid_registration_note');
    }
    final path = <String>[
      '/api/v1/stations/',
      Uri.encodeComponent(stationId),
      '/registration-requests/',
      Uri.encodeComponent(requestId),
      '/decision',
    ].join();
    await _send(
      'POST',
      path,
      body: {
        'decision': decision,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  /// Roles that may be requested for station assignment (server catalogue).
  Future<List<Map<String, dynamic>>> getStationAssignableRoles(
    String stationId,
  ) async {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    final path = <String>[
      '/api/v1/stations/',
      Uri.encodeComponent(stationId),
      '/assignable-roles',
    ].join();
    return _getJsonRecords(path, 'invalid_assignable_roles');
  }

  /// Request a station role assignment for an existing user (server-enforced).
  Future<void> requestStationAssignment({
    required String stationId,
    required String userId,
    required String roleCode,
    String? reason,
  }) async {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    _requirePathIdentifier(userId, 'invalid_user_id');
    final role = roleCode.trim();
    if (role.isEmpty || role.length > 64) {
      throw const MetraApiException(400, 'invalid_assignment_role');
    }
    if (reason != null && (reason.length > 2000 || reason != reason.trim())) {
      throw const MetraApiException(400, 'invalid_assignment_reason');
    }
    final path = <String>[
      '/api/v1/stations/',
      Uri.encodeComponent(stationId),
      '/assignments',
    ].join();
    await _send(
      'POST',
      path,
      body: {
        'userId': userId.trim(),
        'roleCode': role,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  /// Approve or reject a pending station assignment (server-enforced).
  Future<void> decideStationAssignment({
    required String stationId,
    required String assignmentId,
    required String decision,
    String? note,
  }) async {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    _requirePathIdentifier(assignmentId, 'invalid_assignment_id');
    if (decision != 'approve' && decision != 'reject') {
      throw const MetraApiException(400, 'invalid_assignment_decision');
    }
    final path = <String>[
      '/api/v1/stations/',
      Uri.encodeComponent(stationId),
      '/assignments/',
      Uri.encodeComponent(assignmentId),
      '/decision',
    ].join();
    await _send(
      'POST',
      path,
      body: {
        'decision': decision,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  /// Revoke an active station assignment (server-enforced).
  Future<void> revokeStationAssignment({
    required String stationId,
    required String assignmentId,
    String? reason,
  }) async {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    _requirePathIdentifier(assignmentId, 'invalid_assignment_id');
    if (reason != null && (reason.length > 2000 || reason != reason.trim())) {
      throw const MetraApiException(400, 'invalid_assignment_reason');
    }
    final path = <String>[
      '/api/v1/stations/',
      Uri.encodeComponent(stationId),
      '/assignments/',
      Uri.encodeComponent(assignmentId),
      '/revoke',
    ].join();
    await _send(
      'POST',
      path,
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getJsonRecords(
    String path,
    String errorCode,
  ) async {
    final response = await _send('GET', path);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw FormatException(errorCode);
    if (decoded.any((item) => item is! Map)) {
      throw FormatException(errorCode);
    }
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<MetraObservationValidation> validateObservation({
    required String observationType,
    required Map<String, Object?> values,
  }) async {
    if (observationType == 'phenomenon') {
      return _validatePhenomenon(values);
    }

    final route = switch (observationType) {
      'hourly' => '/api/v1/observations/hourly/validate',
      'daily' => '/api/v1/observations/daily/validate',
      _ => throw const MetraApiException(
        400,
        'unsupported_observation_validation',
      ),
    };
    final normalized = <String, String?>{
      for (final entry in values.entries)
        entry.key: _formatValidationValue(
          observationType,
          entry.key,
          entry.value,
        ),
    };
    final response = await _send('POST', route, body: {'values': normalized});
    return _parseValidationResponse(response);
  }

  Future<MetraObservationValidation> _validatePhenomenon(
    Map<String, Object?> values,
  ) async {
    String? asString(Object? value) {
      if (value == null) return null;
      if (value is bool) return value ? 'true' : 'false';
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final body = <String, String?>{
      'phenomenonType': asString(
        values['phenomenonType'] ?? values['phenomenon_type'],
      ),
      'phenomenonDate': asString(
        values['phenomenonDate'] ?? values['phenomenon_date'],
      ),
      'startTime': asString(values['startTime'] ?? values['start_time']),
      'endTime': asString(values['endTime'] ?? values['end_time']),
      'generalNotes': asString(
        values['generalNotes'] ?? values['general_notes'],
      ),
    };
    final response = await _send(
      'POST',
      '/api/v1/observations/phenomena/validate',
      body: body,
    );
    return _parseValidationResponse(response);
  }

  MetraObservationValidation _parseValidationResponse(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('invalid_observation_validation_response');
    }
    final map = Map<String, dynamic>.from(decoded);
    final isValid = map['isValid'];
    final rawIssues = map['issues'];
    if (isValid is! bool || rawIssues is! List) {
      throw const FormatException('invalid_observation_validation_response');
    }

    final issues = <MetraValidationIssue>[];
    for (final item in rawIssues) {
      if (item is! Map) {
        throw const FormatException('invalid_observation_validation_issue');
      }
      final row = Map<String, dynamic>.from(item);
      final field = row['field'];
      final message = row['message'];
      if (field is! String ||
          field.trim().isEmpty ||
          message is! String ||
          message.trim().isEmpty) {
        throw const FormatException('invalid_observation_validation_issue');
      }
      issues.add(MetraValidationIssue(field: field, message: message));
    }

    if (isValid != issues.isEmpty) {
      throw const FormatException('inconsistent_observation_validation_response');
    }

    return MetraObservationValidation(
      isValid: isValid,
      issues: List<MetraValidationIssue>.unmodifiable(issues),
    );
  }

  String? _formatValidationValue(String type, String field, Object? value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty || raw == '#') return raw;

    String integer(int width) {
      final parsed = int.tryParse(raw);
      return parsed == null ? raw : parsed.toString().padLeft(width, '0');
    }

    String decimal(int width, {bool explicitPositiveSign = false}) {
      final negative = raw.startsWith('-');
      final positive = raw.startsWith('+');
      final unsigned = negative || positive ? raw.substring(1) : raw;
      final parts = unsigned.split('.');
      if (parts.length > 2) return raw;
      final whole = int.tryParse(parts.first);
      if (whole == null) return raw;
      final fraction = parts.length == 2 ? parts.last : '0';
      if (fraction.length != 1 || int.tryParse(fraction) == null) return raw;
      final sign = negative
          ? '-'
          : ((explicitPositiveSign || positive) ? '+' : '');
      return <String>[
        sign,
        whole.toString().padLeft(width, '0'),
        '.',
        fraction,
      ].join();
    }

    if (type == 'hourly') {
      if (const {'dryTemp', 'wetTemp', 'dewPoint'}.contains(field)) {
        return decimal(2, explicitPositiveSign: true);
      }
      if (const {'stationPressure', 'seaLevelPressure'}.contains(field)) {
        return decimal(4);
      }
      if (field == 'relativeHumidity' || field == 'visibility') {
        return integer(3);
      }
      if (const {
        'windDirection',
        'avgWindDirection',
        'windSpeed',
        'avgWindSpeed',
      }.contains(field)) {
        return integer(2);
      }
      if (field == 'currentWeather') return integer(2);
      if (const {
        'pastWeather',
        'totalCloudCover',
        'cloud1Amount',
        'cloud2Amount',
        'cloud3Amount',
        'cloud4Amount',
        'cover12',
        'cover123',
        'pressureShape',
      }.contains(field)) {
        return integer(1);
      }
      if (field == 'pressureSlope') return decimal(1);
      if (field == 'vaporPressure' || field == 'vaporPressureDiff') {
        return decimal(2);
      }
      if (field == 'precipitationAmount') return decimal(3);
    }

    if (type == 'daily') {
      if (field == 'minTemp' || field == 'maxTemp') return decimal(2);
      if (field == 'precipitation') return decimal(3);
      if (field == 'snowThickness' ||
          field == 'sunshinePercentage' ||
          field == 'maxHumidity') {
        return integer(3);
      }
      if (field == 'evaporation' ||
          field == 'sunshineDuration' ||
          field == 'maxGustTime' ||
          field == 'maxHumidityTime' ||
          field == 'minHumidityTime') {
        return decimal(2);
      }
      if (field == 'maxGustSpeed' ||
          field == 'maxGustDirection' ||
          field == 'minHumidity') {
        return integer(2);
      }
    }
    return raw;
  }

  /// Loads server-authoritative access context for the signed-in user.
  Future<MetraAccessContext> getAccessContext() async {
    final response = await _send('GET', '/api/v1/me/access-context');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('invalid_access_context');
    }
    final map = Map<String, dynamic>.from(decoded);
    String? stringValue(dynamic value) => value is String ? value : null;
    final userId =
        stringValue(map['userId']) ?? stringValue(map['user_id']) ?? '';
    if (userId.trim().isEmpty) {
      throw const FormatException('invalid_access_context_user');
    }
    final accountState =
        stringValue(map['accountState']) ?? stringValue(map['account_state']);
    final stationsRaw = map['stations'];
    final stationPermissions = <String, Set<String>>{};
    final stationRoles = <String, String>{};
    final authoritiesRaw = map['authorities'];
    final authorityPermissions = <String, Set<String>>{};
    final authorityRoles = <String, String>{};
    if (stationsRaw is List) {
      for (final item in stationsRaw) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final stationId =
            stringValue(row['stationId']) ?? stringValue(row['station_id']) ?? '';
        if (stationId.trim().isEmpty) continue;
        final role =
            stringValue(row['roleCode']) ?? stringValue(row['role_code']);
        if (role != null && role.trim().isNotEmpty) {
          stationRoles[stationId.trim()] = role.trim();
        }
        final perms = <String>{};
        final rawPerms = row['permissions'];
        if (rawPerms is List) {
          for (final p in rawPerms) {
            final code = stringValue(p)?.trim() ?? '';
            if (code.isNotEmpty) perms.add(code);
          }
        }
        stationPermissions[stationId.trim()] = perms;
      }
    }
    if (authoritiesRaw is List) {
      for (final item in authoritiesRaw) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final id = stringValue(row['authorityId']) ?? stringValue(row['authority_id']) ?? '';
        if (id.trim().isEmpty) continue;
        final role = stringValue(row['roleCode']) ?? stringValue(row['role_code']);
        if (role != null && role.trim().isNotEmpty) authorityRoles[id.trim()] = role.trim();
        final permissions = <String>{};
        final raw = row['permissions'];
        if (raw is List) {
          for (final p in raw) {
            final code = stringValue(p)?.trim() ?? '';
            if (code.isNotEmpty) permissions.add(code);
          }
        }
        authorityPermissions[id.trim()] = permissions;
      }
    }
    return MetraAccessContext.resolved(
      userId: userId,
      accountState: accountState,
      stationPermissions: stationPermissions,
      stationRoles: stationRoles,
      authorityPermissions: authorityPermissions,
      authorityRoles: authorityRoles,
    );
  }

  Future<void> submitObservation({
    required String stationId,
    required String idempotencyKey,
    required String observationType,
    required DateTime observedAt,
    required Map<String, dynamic> payload,
    bool submit = false,
  }) async {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    _requirePathIdentifier(idempotencyKey, 'invalid_idempotency_key');
    if (!const {'hourly', 'daily', 'phenomenon'}.contains(observationType)) {
      throw const MetraApiException(400, 'unsupported_observation_type');
    }
    await _send(
      'POST',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations',
      body: {
        'idempotencyKey': idempotencyKey,
        'observationType': observationType,
        'observedAt': observedAt.toUtc().toIso8601String(),
        'payload': payload,
        'submit': submit,
      },
    );
  }

  /// Requestable roles for registration (authenticated).
  Future<List<Map<String, dynamic>>> getRegistrationRoles() async {
    final response = await _send('GET', '/api/v1/registration-roles');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final rows = decoded is List
        ? decoded
        : decoded is Map
        ? (decoded['roles'] ?? decoded['data'])
        : null;
    if (rows is! List || rows.any((item) => item is! Map)) {
      throw const FormatException('invalid_registration_roles_response');
    }
    return rows
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  /// Current user's registration status payload (shape depends on RPC).
  Future<Map<String, dynamic>> getMyRegistrationStatus() async {
    final response = await _send('GET', '/api/v1/account/registration-status');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    if (decoded is List && decoded.length == 1 && decoded.first is Map) {
      return Map<String, dynamic>.from(decoded.first as Map);
    }
    throw const FormatException('invalid_registration_status_response');
  }

  /// Submit station registration request — fields match server contract only.
  Future<Map<String, dynamic>> submitRegistrationRequest({
    required String firstName,
    required String fatherName,
    required String lastName,
    required String phone,
    required String roleCode,
    required String stationId,
    required String idempotencyKey,
    String termsVersion = 'metra-terms-2026-11',
  }) async {
    _requirePathIdentifier(stationId, 'invalid_station_id');
    final response = await _send(
      'POST',
      '/api/v1/registration-requests',
      body: {
        'firstName': firstName,
        'fatherName': fatherName,
        'lastName': lastName,
        'phone': phone,
        'roleCode': roleCode,
        'stationId': stationId,
        'termsVersion': termsVersion,
        'idempotencyKey': idempotencyKey,
      },
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('invalid_registration_submission_response');
  }

  void _requirePathIdentifier(String value, String errorCode) {
    if (value.trim().isEmpty ||
        value != value.trim() ||
        value.contains(RegExp(r'\s')) ||
        value.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
      throw MetraApiException(400, errorCode);
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (!isConfigured) {
      throw const MetraApiException(503, 'api_not_configured');
    }
    String? token;
    try {
      token = await accessTokenProvider().timeout(_requestTimeout);
    } on TimeoutException {
      throw const MetraApiException(0, 'timeout');
    }
    if (token == null || token.trim().isEmpty) {
      throw const MetraApiException(401, 'authentication_required');
    }
    final uri = _baseUri!.resolve(path);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_requestTimeout);
      response = await http.Response.fromStream(streamed)
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const MetraApiException(0, 'timeout');
    } on http.ClientException {
      throw const MetraApiException(0, 'network_unavailable');
    } on Exception {
      throw const MetraApiException(0, 'network_unavailable');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MetraApiException(response.statusCode, 'request_failed');
    }
    return response;
  }

  void close() => _client.close();
}
