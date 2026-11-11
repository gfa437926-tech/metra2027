import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../api_config.dart';

const metraApiBaseUrl = ApiConfig.baseUrl;

class MetraApiException implements Exception {
  const MetraApiException(this.statusCode, this.code);
  final int statusCode;
  final String code;
  @override
  String toString() => 'MetraApiException($statusCode, $code)';
}

class ObservationQueueItem {
  const ObservationQueueItem({required this.id, required this.stationId,
    required this.observationType, required this.observedAt,
    required this.status,
    this.reviewNote, this.payload = const {}});
  final String id;
  final String stationId;
  final String observationType;
  final DateTime observedAt;
  final String status;
  final String? reviewNote;
  final Map<String, dynamic> payload;

  factory ObservationQueueItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final stationId = json['station_id'];
    final type = json['observation_type'];
    final observedAt = DateTime.tryParse('${json['observed_at'] ?? ''}');
    if (id is! String || stationId is! String || type is! String || observedAt == null) {
      throw const FormatException('invalid_observation_queue_item');
    }
    final rawPayload = json['payload'];
    return ObservationQueueItem(id: id, stationId: stationId,
      observationType: type, observedAt: observedAt,
      status: json['status'] is String ? json['status'] as String : 'submitted',
      reviewNote: json['review_note'] is String ? json['review_note'] as String : null,
      payload: rawPayload is Map<String, dynamic> ? rawPayload : const {});
  }
}

class StationDirectoryItem {
  const StationDirectoryItem({required this.id, required this.localCode,
    required this.nameArabic, required this.nameEnglish, required this.stationType,
    required this.operationalStatus, required this.approvalStatus, required this.isDemo,
    this.latitude, this.longitude, this.wmoStationId, this.elevationM,
    this.coordinateSource, this.coordinateAccuracyM});
  final String id, localCode, nameArabic, nameEnglish, stationType;
  final String operationalStatus, approvalStatus;
  final bool isDemo;
  final double? latitude, longitude;
  final String? wmoStationId;
  final double? elevationM;
  final String? coordinateSource;
  final double? coordinateAccuracyM;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasValidCoordinates => hasCoordinates &&
      latitude! >= -90 && latitude! <= 90 &&
      longitude! >= -180 && longitude! <= 180;
  factory StationDirectoryItem.fromJson(Map<String, dynamic> json) {
    for (final key in ['id','local_station_code','name_ar','name_en','station_type','operational_status','approval_status']) {
      if (json[key] is! String) throw const FormatException('invalid_station_directory_item');
    }
    double? number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
    double? lat, lon;
    Map<String, dynamic>? point;
    final coords = json['station_coordinates'];
    if (coords is List && coords.isNotEmpty && coords.first is Map) {
      point = Map<String, dynamic>.from(coords.first as Map);
      lat = number(point['latitude']);
      lon = number(point['longitude']);
    }
    return StationDirectoryItem(id: json['id'] as String,
      localCode: json['local_station_code'] as String,
      nameArabic: json['name_ar'] as String, nameEnglish: json['name_en'] as String,
      stationType: json['station_type'] as String,
      operationalStatus: json['operational_status'] as String,
      approvalStatus: json['approval_status'] as String, isDemo: json['is_demo'] == true,
      latitude: lat, longitude: lon, wmoStationId: json['wmo_station_id'] as String?,
      elevationM: number(json['elevation_m']),
      coordinateSource: point?['coordinate_source'] is String
          ? point!['coordinate_source'] as String
          : null,
      coordinateAccuracyM: point == null ? null : number(point['accuracy_m']));
  }
}


/// API wrapper. Supply a current Supabase access token from the auth layer.
class MetraApiClient {
  MetraApiClient({required this.accessTokenProvider,
    String baseUrl = metraApiBaseUrl, http.Client? client})
      : _baseUri = Uri.tryParse(baseUrl.trim()), _client = client ?? http.Client();

  final Future<String?> Function() accessTokenProvider;
  final Uri? _baseUri;
  final http.Client _client;
  bool get isConfigured => ApiConfig.isValidUrl(_baseUri?.toString() ?? '');

  Future<List<StationDirectoryItem>> getStationDirectory({
    int limit = 250, int offset = 0, String? stationType,
  }) async {
    if (limit < 1 || limit > 500 || offset < 0) {
      throw const MetraApiException(400, 'invalid_pagination');
    }
    if (stationType != null && !const {'classic', 'automatic', 'synoptic'}.contains(stationType)) {
      throw const MetraApiException(400, 'invalid_station_type');
    }
    final filter = stationType == null ? '' : '&stationType=$stationType';
    final response = await _send('GET', '/api/v1/stations?limit=$limit&offset=$offset$filter');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('invalid_station_directory');
    return decoded.map((item) => StationDirectoryItem.fromJson(
      Map<String, dynamic>.from(item as Map))).toList(growable: false);
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
    throw const MetraApiException(413, 'station_directory_limit_exceeded');
  }


  /// Uses the authoritative forecasting comparison endpoint. This reports
  /// catalogue geography/elevation only; it never fabricates live observations.
  /// Catalogue profile for forecasting centre. Values are not live observations.
  Future<Map<String, dynamic>> getForecastingStationProfile(String stationId) async {
    final response = await _send(
      'GET',
      '/api/v1/forecasting/stations/${Uri.encodeComponent(stationId)}',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('invalid_forecasting_station_profile');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> compareForecastingStations(
    List<String> stationIds,
  ) async {
    if (stationIds.length < 2 || stationIds.length > 12) {
      throw const MetraApiException(400, 'compare_requires_2_to_12_stations');
    }
    if (stationIds.toSet().length != stationIds.length) {
      throw const MetraApiException(400, 'duplicate_station_ids');
    }
    final response = await _send(
      'POST',
      '/api/v1/forecasting/compare',
      body: {'stationIds': stationIds},
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map ||
        decoded['stations'] is! List ||
        decoded['pairs'] is! List) {
      throw const FormatException('invalid_forecasting_comparison_response');
    }
    return Map<String, dynamic>.from(decoded);
  }


  Future<List<ObservationQueueItem>> getReturnedObservations(String stationId, {int limit = 50}) async {
    if (limit < 1 || limit > 100) throw const MetraApiException(400, 'invalid_limit');
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations/returned?limit=$limit',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('invalid_returned_queue');
    return decoded
        .map((item) => ObservationQueueItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<List<ObservationQueueItem>> getReviewQueue(String stationId, {int limit = 50}) async {
    if (limit < 1 || limit > 100) throw const MetraApiException(400, 'invalid_limit');
    final response = await _send('GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations?limit=$limit');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('invalid_observation_queue');
    return decoded.map((item) => ObservationQueueItem.fromJson(
      Map<String, dynamic>.from(item as Map))).toList(growable: false);
  }

  Future<void> decideObservation({
    required String stationId,
    required String observationId,
    required String decision,
    String? note,
  }) async {
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
      body: {'decision': decision, 'note': note},
    );
  }


  Future<void> resubmitObservation({
    required String stationId,
    required String observationId,
    Map<String, dynamic>? payload,
  }) async {
    await _send(
      'POST',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations/${Uri.encodeComponent(observationId)}/resubmit',
      body: {'payload': payload},
    );
  }

  Future<Map<String, dynamic>> validateWeatherPhenomenon({
    required String phenomenonType,
    required String phenomenonDate,
    required String startTime,
    String? endTime,
    String? generalNotes,
  }) async {
    final response = await _send(
      'POST',
      '/api/v1/observations/phenomena/validate',
      body: {
        'phenomenonType': phenomenonType,
        'phenomenonDate': phenomenonDate,
        'startTime': startTime,
        'endTime': endTime,
        'generalNotes': generalNotes,
      },
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('invalid_phenomenon_validation_response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// Submits the canonical observation envelope and requires a persisted receipt.
  /// A 2xx response without the database observation id is not treated as success.
  Future<Map<String, dynamic>> submitObservation({required String stationId,
    required String idempotencyKey, required String observationType,
    required DateTime observedAt, required Map<String, dynamic> payload,
    bool submit = false}) async {
    final response = await _send('POST', '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations',
      body: {'idempotencyKey': idempotencyKey, 'observationType': observationType,
        'observedAt': observedAt.toUtc().toIso8601String(),
        'payload': payload, 'submit': submit});
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['id'] is! String ||
        (decoded['id'] as String).trim().isEmpty) {
      throw const FormatException('observation_persistence_receipt_missing_id');
    }
    return Map<String, dynamic>.from(decoded);
  }


  Future<List<Map<String, dynamic>>> listEquipmentFaults(String stationId, {int limit = 50}) async {
    if (limit < 1 || limit > 100) throw const MetraApiException(400, 'invalid_limit');
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/equipment-faults?limit=$limit',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('invalid_equipment_fault_list');
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList(growable: false);
  }

  Future<void> submitEquipmentFault({
    required String stationId,
    required String equipmentCategory,
    required String equipmentName,
    required String description,
    required String severity,
    required DateTime occurredAt,
    bool isOperationallyBlocking = false,
  }) async {
    await _send(
      'POST',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/equipment-faults',
      body: {
        'equipmentCategory': equipmentCategory,
        'equipmentName': equipmentName,
        'description': description,
        'severity': severity,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'isOperationallyBlocking': isOperationallyBlocking,
      },
    );
  }


  Future<Map<String, dynamic>> getEquipmentFaultById({
    required String stationId,
    required String faultId,
  }) async {
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/equipment-faults/${Uri.encodeComponent(faultId)}',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const FormatException('invalid_equipment_fault');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> transitionEquipmentFault({
    required String stationId,
    required String faultId,
    required String toStatus,
    String? note,
    int? progressPercent,
    String? assignedTo,
  }) async {
    await _send(
      'POST',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/equipment-faults/${Uri.encodeComponent(faultId)}/transitions',
      body: {
        'toStatus': toStatus,
        'note': note,
        'progressPercent': progressPercent,
        'assignedTo': assignedTo,
      },
    );
  }


  Future<List<Map<String, dynamic>>> listSupportIncidents(String stationId, {int limit = 50}) async {
    if (limit < 1 || limit > 100) throw const MetraApiException(400, 'invalid_limit');
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/support-incidents?limit=$limit',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('invalid_support_incident_list');
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList(growable: false);
  }


  Future<Map<String, dynamic>> getSupportIncidentById({
    required String stationId,
    required String incidentId,
  }) async {
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/support-incidents/${Uri.encodeComponent(incidentId)}',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const FormatException('invalid_support_incident');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> transitionSupportIncident({
    required String stationId,
    required String incidentId,
    required String toStatus,
    String? note,
    String? assignedTo,
  }) async {
    await _send(
      'POST',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/support-incidents/${Uri.encodeComponent(incidentId)}/transitions',
      body: {
        'toStatus': toStatus,
        'note': note,
        'assignedTo': assignedTo,
      },
    );
  }

  Future<void> submitSupportIncident({
    required String stationId,
    required String kind,
    required String category,
    required String title,
    required String description,
    required String severity,
    required DateTime occurredAt,
    String? affectedAsset,
    bool impactsOperations = false,
  }) async {
    await _send(
      'POST',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/support-incidents',
      body: {
        'kind': kind,
        'category': category,
        'title': title,
        'description': description,
        'affectedAsset': affectedAsset,
        'severity': severity,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'impactsOperations': impactsOperations,
      },
    );
  }



  Future<List<Map<String, dynamic>>> listRegistrationRequests(
    String stationId, {
    bool systemStage = false,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 100) throw const MetraApiException(400, 'invalid_limit');
    final String path = systemStage
        ? '/api/v1/stations/${Uri.encodeComponent(stationId)}/system-registration-requests?limit=$limit'
        : '/api/v1/stations/${Uri.encodeComponent(stationId)}/registration-requests?limit=$limit';
    final response = await _send('GET', path);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('invalid_registration_request_list');
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<void> decideRegistrationRequest({
    required String stationId,
    required String requestId,
    required String decision,
    String? note,
    bool systemStage = false,
  }) async {
    final String path = systemStage
        ? '/api/v1/stations/${Uri.encodeComponent(stationId)}/system-registration-requests/${Uri.encodeComponent(requestId)}/decision'
        : '/api/v1/stations/${Uri.encodeComponent(stationId)}/registration-requests/${Uri.encodeComponent(requestId)}/decision';
    await _send(
      'POST',
      path,
      body: {
        'decision': decision,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> listStationUsers(
    String stationId, {
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 500) throw const MetraApiException(400, 'invalid_limit');
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/users?limit=$limit',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is List) {
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
    }
    if (decoded is Map && decoded['items'] is List) {
      return (decoded['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
    }
    throw const FormatException('invalid_station_user_list');
  }

  Future<List<Map<String, dynamic>>> listAssignableRoles(String stationId) async {
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/assignable-roles',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('invalid_assignable_role_list');
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<void> requestStationAssignment({
    required String stationId,
    required String userId,
    required String roleCode,
    required String reason,
    required String validFrom,
    String? validTo,
  }) async {
    await _send(
      'POST',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/assignments',
      body: {
        'userId': userId,
        'roleCode': roleCode,
        'reason': reason,
        'validFrom': validFrom,
        if (validTo != null && validTo.isNotEmpty) 'validTo': validTo,
      },
    );
  }

  Future<void> decideStationAssignment({
    required String stationId,
    required String assignmentId,
    required String decision,
    String? note,
  }) async {
    await _send(
      'POST',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/assignments/${Uri.encodeComponent(assignmentId)}/decision',
      body: {
        'decision': decision,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<void> revokeStationAssignment({
    required String stationId,
    required String assignmentId,
    required String reason,
  }) async {
    await _send(
      'POST',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/assignments/${Uri.encodeComponent(assignmentId)}/revoke',
      body: {'reason': reason},
    );
  }

  Future<List<Map<String, dynamic>>> listArchiveConfirmations(
    String stationId, {
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) throw const MetraApiException(400, 'invalid_limit');
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/archive-confirmations?limit=$limit',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('invalid_archive_confirmation_list');
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList(growable: false);
  }

  Future<Map<String, dynamic>> confirmManualArchive({
    required String stationId,
    required String reportKind,
    required String periodStartUtc,
    required String periodEndUtc,
    required String excelFileName,
    String? note,
  }) async {
    final response = await _send(
      'POST',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/archive-confirmations',
      body: {
        'reportKind': reportKind,
        'periodStartUtc': periodStartUtc,
        'periodEndUtc': periodEndUtc,
        'excelFileName': excelFileName,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const FormatException('invalid_archive_confirmation');
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> archiveMonthlySummary({
    required String stationId,
    required int year,
    required int month,
  }) async {
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/archive-confirmations/monthly-summary?year=$year&month=$month',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const FormatException('invalid_archive_monthly_summary');
    return Map<String, dynamic>.from(decoded);
  }


  Future<List<Map<String, dynamic>>> getRequestableRegistrationRoles() async {
    final response = await _send('GET', '/api/v1/registration-roles');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) throw const FormatException('invalid_registration_roles');
    return decoded.map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> getMyRegistrationStatus() async {
    final response = await _send('GET', '/api/v1/account/registration-status');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const FormatException('invalid_registration_status');
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> submitRegistrationRequest({
    required String firstName,
    required String fatherName,
    required String lastName,
    String? phone,
    required String roleCode,
    required String stationId,
    required String termsVersion,
    required String idempotencyKey,
  }) async {
    final response = await _send('POST', '/api/v1/registration-requests', body: {
      'firstName': firstName,
      'fatherName': fatherName,
      'lastName': lastName,
      'phone': phone,
      'roleCode': roleCode,
      'stationId': stationId,
      'termsVersion': termsVersion,
      'idempotencyKey': idempotencyKey,
    });
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const FormatException('invalid_registration_receipt');
    return Map<String, dynamic>.from(decoded);
  }

  Future<http.Response> _send(String method, String path,
      {Map<String, dynamic>? body}) async {
    if (!isConfigured) throw const MetraApiException(503, 'api_not_configured');
    final token = await accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const MetraApiException(401, 'authentication_required');
    }
    final uri = _baseUri!.resolve(path);
    final request = http.Request(method, uri)..headers.addAll({
      'Accept': 'application/json', 'Authorization': 'Bearer $token'});
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(await _client.send(request));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MetraApiException(response.statusCode, 'request_failed');
    }
    return response;
  }

  void close() => _client.close();
}
