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
  const ObservationQueueItem(
      {required this.id,
      required this.stationId,
      required this.observationType,
      required this.observedAt,
      required this.status,
      this.payload = const {}});
  final String id;
  final String stationId;
  final String observationType;
  final DateTime observedAt;
  final String status;
  final Map<String, dynamic> payload;

  factory ObservationQueueItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final stationId = json['station_id'];
    final type = json['observation_type'];
    final observedAt = DateTime.tryParse('${json['observed_at'] ?? ''}');
    if (id is! String ||
        stationId is! String ||
        type is! String ||
        observedAt == null) {
      throw const FormatException('invalid_observation_queue_item');
    }
    final rawPayload = json['payload'];
    return ObservationQueueItem(
        id: id,
        stationId: stationId,
        observationType: type,
        observedAt: observedAt,
        status:
            json['status'] is String ? json['status'] as String : 'submitted',
        payload: rawPayload is Map<String, dynamic> ? rawPayload : const {});
  }
}

class ObservationArchiveItem {
  const ObservationArchiveItem({
    required this.id,
    required this.stationId,
    required this.sourceSystem,
    required this.sourceTable,
    required this.sourceRecordId,
    required this.observationType,
    required this.payload,
    required this.importedAtUtc,
    this.observedAtUtc,
  });

  final String id,
      stationId,
      sourceSystem,
      sourceTable,
      sourceRecordId,
      observationType;
  final Map<String, dynamic> payload;
  final DateTime importedAtUtc;
  final DateTime? observedAtUtc;

  factory ObservationArchiveItem.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw const FormatException('invalid_observation_archive_item');
      }
      return value;
    }

    final importedAt = DateTime.tryParse('${json['importedAtUtc'] ?? ''}');
    final observedAtRaw = json['observedAtUtc'];
    final observedAt =
        observedAtRaw == null ? null : DateTime.tryParse('$observedAtRaw');
    final rawPayload = json['payload'];
    if (importedAt == null ||
        (observedAtRaw != null && observedAt == null) ||
        rawPayload is! Map) {
      throw const FormatException('invalid_observation_archive_item');
    }

    return ObservationArchiveItem(
      id: requiredString('id'),
      stationId: requiredString('stationId'),
      sourceSystem: requiredString('sourceSystem'),
      sourceTable: requiredString('sourceTable'),
      sourceRecordId: requiredString('sourceRecordId'),
      observationType: requiredString('observationType'),
      observedAtUtc: observedAt?.toUtc(),
      importedAtUtc: importedAt.toUtc(),
      payload: Map<String, dynamic>.from(rawPayload),
    );
  }
}

class ObservationArchivePage {
  const ObservationArchivePage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<ObservationArchiveItem> items;
  final bool hasMore;
  final String? nextCursor;

  factory ObservationArchivePage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final hasMore = json['hasMore'];
    final nextCursor = json['nextCursor'];
    if (rawItems is! List ||
        hasMore is! bool ||
        (nextCursor != null && nextCursor is! String)) {
      throw const FormatException('invalid_observation_archive_page');
    }
    return ObservationArchivePage(
      items: rawItems
          .map((item) => ObservationArchiveItem.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      hasMore: hasMore,
      nextCursor: nextCursor as String?,
    );
  }
}

class StationAuditEvent {
  const StationAuditEvent({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.actorId,
    required this.occurredAt,
    this.reason,
    this.targetUserId,
    this.roleCode,
    this.previousStatus,
    this.resultingStatus,
    this.validFrom,
    this.validTo,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String action;
  final String actorId;
  final DateTime occurredAt;
  final String? reason;
  final String? targetUserId;
  final String? roleCode;
  final String? previousStatus;
  final String? resultingStatus;
  final String? validFrom;
  final String? validTo;

  factory StationAuditEvent.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw const FormatException('invalid_station_audit_event');
      }
      return value;
    }

    String? optionalString(String key) =>
        json[key] is String ? json[key] as String : null;

    final occurredAt = DateTime.tryParse('${json['occurred_at'] ?? ''}');
    if (occurredAt == null) {
      throw const FormatException('invalid_station_audit_event');
    }

    return StationAuditEvent(
      id: requiredString('id'),
      entityType: requiredString('entity_type'),
      entityId: requiredString('entity_id'),
      action: requiredString('action'),
      actorId: requiredString('actor_id'),
      occurredAt: occurredAt,
      reason: optionalString('reason'),
      targetUserId: optionalString('target_user_id'),
      roleCode: optionalString('role_code'),
      previousStatus: optionalString('previous_status'),
      resultingStatus: optionalString('resulting_status'),
      validFrom: optionalString('valid_from'),
      validTo: optionalString('valid_to'),
    );
  }
}

class StationDirectoryItem {
  const StationDirectoryItem(
      {required this.id,
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
      this.coordinateAccuracyM});
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
      'approval_status'
    ]) {
      if (json[key] is! String)
        throw const FormatException('invalid_station_directory_item');
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
        coordinateAccuracyM:
            point == null ? null : number(point['accuracy_m']));
  }
}

/// Generic catalogue / queue row from .NET JSON (snake_case or camelCase).
class MetraJsonRow {
  const MetraJsonRow(this.fields);
  final Map<String, dynamic> fields;

  String? stringValue(String snake, [String? camel]) {
    final a = fields[snake];
    if (a is String && a.isNotEmpty) return a;
    if (camel != null) {
      final b = fields[camel];
      if (b is String && b.isNotEmpty) return b;
    }
    return null;
  }

  String displayTitle() =>
      stringValue('name_ar', 'nameAr') ??
      stringValue('display_name', 'displayName') ??
      stringValue('email') ??
      stringValue('role_code', 'roleCode') ??
      stringValue('permission_code', 'permissionCode') ??
      stringValue('local_station_code', 'localStationCode') ??
      stringValue('id') ??
      'عنصر';
  String? displaySubtitle() =>
      stringValue('name_en', 'nameEn') ??
      stringValue('status') ??
      stringValue('role_code', 'roleCode') ??
      stringValue('permission_code', 'permissionCode');
}

List<MetraJsonRow> _parseJsonRowList(dynamic decoded, String errorCode) {
  List? list;
  if (decoded is List) {
    list = decoded;
  } else if (decoded is Map) {
    final map = Map<String, dynamic>.from(decoded);
    for (final key in ['items', 'data', 'rows', 'results', 'value']) {
      final candidate = map[key];
      if (candidate is List) {
        list = candidate;
        break;
      }
    }
    // Some RPCs return a single object instead of an array.
    if (list == null) {
      return [MetraJsonRow(map)];
    }
  }
  if (list == null) {
    throw FormatException(errorCode);
  }
  final rows = <MetraJsonRow>[];
  for (final item in list) {
    if (item is Map) {
      rows.add(MetraJsonRow(Map<String, dynamic>.from(item)));
    }
  }
  return rows;
}

Map<String, dynamic> _parseJsonObject(dynamic decoded, String errorCode) {
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  throw FormatException(errorCode);
}

/// API wrapper. Supply a current Supabase access token from the auth layer.
class MetraApiClient {
  MetraApiClient(
      {required this.accessTokenProvider,
      String baseUrl = metraApiBaseUrl,
      http.Client? client})
      : _baseUri = Uri.tryParse(baseUrl.trim()),
        _client = client ?? http.Client();

  final Future<String?> Function() accessTokenProvider;
  final Uri? _baseUri;
  final http.Client _client;
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
        'GET', '/api/v1/stations?limit=$limit&offset=$offset$filter');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List)
      throw const FormatException('invalid_station_directory');
    return decoded
        .map((item) => StationDirectoryItem.fromJson(
            Map<String, dynamic>.from(item as Map)))
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
    throw const MetraApiException(413, 'station_directory_limit_exceeded');
  }

  Future<List<StationAuditEvent>> getStationAuditLog(String stationId,
      {int limit = 100}) async {
    if (stationId.trim().isEmpty) {
      throw const MetraApiException(400, 'invalid_station_id');
    }
    if (limit < 1 || limit > 250) {
      throw const MetraApiException(400, 'invalid_limit');
    }
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/audit-log?limit=$limit',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('invalid_station_audit_log');
    }
    return decoded
        .map((item) => StationAuditEvent.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<List<ObservationQueueItem>> getReviewQueue(String stationId,
      {int limit = 50}) async {
    if (limit < 1 || limit > 100)
      throw const MetraApiException(400, 'invalid_limit');
    final response = await _send('GET',
        '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations?limit=$limit');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List)
      throw const FormatException('invalid_observation_queue');
    return decoded
        .map((item) => ObservationQueueItem.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<ObservationArchivePage> getObservationArchive(
    String stationId, {
    String? observationType,
    DateTime? fromUtc,
    DateTime? toUtc,
    int limit = 50,
    String? cursor,
  }) async {
    if (stationId.trim().isEmpty) {
      throw const MetraApiException(400, 'invalid_station_id');
    }
    if (limit < 1 || limit > 100 || (cursor != null && cursor.length > 2048)) {
      throw const MetraApiException(400, 'invalid_pagination');
    }
    const types = {
      'daily',
      'hourly',
      'climate',
      'soil',
      'agricultural',
      'phenomenon',
      'fieldclimate'
    };
    if (observationType != null && !types.contains(observationType)) {
      throw const MetraApiException(400, 'invalid_observation_type');
    }
    if ((fromUtc != null && !fromUtc.isUtc) ||
        (toUtc != null && !toUtc.isUtc)) {
      throw const MetraApiException(400, 'utc_offset_required');
    }
    if (fromUtc != null && toUtc != null && !fromUtc.isBefore(toUtc)) {
      throw const MetraApiException(400, 'invalid_time_range');
    }
    final query = <String, String>{
      'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
      if (observationType != null) 'observationType': observationType,
      if (fromUtc != null) 'fromUtc': fromUtc.toIso8601String(),
      if (toUtc != null) 'toUtc': toUtc.toIso8601String(),
    };
    final path = Uri(
      path:
          '/api/v1/stations/${Uri.encodeComponent(stationId)}/observation-archive',
      queryParameters: query,
    ).toString();
    final response = await _send('GET', path);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('invalid_observation_archive_response');
    }
    return ObservationArchivePage.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<ObservationArchiveItem> getObservationArchiveDetail(
    String stationId,
    String observationId,
  ) async {
    if (stationId.trim().isEmpty || observationId.trim().isEmpty) {
      throw const MetraApiException(400, 'invalid_archive_identifier');
    }
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/observation-archive/${Uri.encodeComponent(observationId)}',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('invalid_observation_archive_detail');
    }
    return ObservationArchiveItem.fromJson(Map<String, dynamic>.from(decoded));
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

  Future<void> submitObservation(
      {required String stationId,
      required String idempotencyKey,
      required String observationType,
      required DateTime observedAt,
      required Map<String, dynamic> payload,
      bool submit = false}) async {
    await _send('POST',
        '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations',
        body: {
          'idempotencyKey': idempotencyKey,
          'observationType': observationType,
          'observedAt': observedAt.toUtc().toIso8601String(),
          'payload': payload,
          'submit': submit
        });
  }

  /// GET /api/v1/stations/{stationId}/users — station-scoped user directory.
  Future<List<MetraJsonRow>> getStationUsers(String stationId,
      {int limit = 100}) async {
    if (stationId.trim().isEmpty) {
      throw const MetraApiException(400, 'invalid_station_id');
    }
    if (limit < 1 || limit > 500) {
      throw const MetraApiException(400, 'invalid_limit');
    }
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/users?limit=$limit',
    );
    return _parseJsonRowList(
        jsonDecode(response.body), 'invalid_station_users');
  }

  /// GET /api/v1/registration-roles
  Future<List<MetraJsonRow>> getRegistrationRoles() async {
    final response = await _send('GET', '/api/v1/registration-roles');
    return _parseJsonRowList(
        jsonDecode(response.body), 'invalid_registration_roles');
  }

  /// GET /api/v1/account/registration-status
  Future<Map<String, dynamic>> getMyRegistrationStatus() async {
    final response = await _send('GET', '/api/v1/account/registration-status');
    return _parseJsonObject(
        jsonDecode(response.body), 'invalid_registration_status');
  }

  /// GET /api/v1/authorities
  Future<List<MetraJsonRow>> getAuthorities() async {
    final response = await _send('GET', '/api/v1/authorities');
    return _parseJsonRowList(
        jsonDecode(response.body), 'invalid_authority_catalogue');
  }

  /// GET /api/v1/authorities/{id}/access-queue
  Future<List<MetraJsonRow>> getAuthorityAccessQueue(
    String authorityId, {
    required String kind,
    int limit = 100,
  }) async {
    if (authorityId.trim().isEmpty) {
      throw const MetraApiException(400, 'invalid_authority_id');
    }

    const allowedKinds = {
      'membership',
      'permission_grant',
      'membership_active',
      'permission_grant_active',
    };

    if (!allowedKinds.contains(kind)) {
      throw const MetraApiException(400, 'invalid_access_queue_kind');
    }

    if (limit < 1 || limit > 100) {
      throw const MetraApiException(400, 'invalid_limit');
    }

    final query = Uri(queryParameters: {
      'kind': kind,
      'limit': '$limit',
    }).query;

    final response = await _send(
      'GET',
      '/api/v1/authorities/${Uri.encodeComponent(authorityId)}/access-queue?$query',
    );

    return _parseJsonRowList(
      jsonDecode(response.body),
      'invalid_authority_access_queue',
    );
  }

  /// GET /api/v1/authorities/{id}/access-audit
  Future<List<MetraJsonRow>> getAuthorityAccessAudit(String authorityId,
      {int limit = 100}) async {
    if (authorityId.trim().isEmpty) {
      throw const MetraApiException(400, 'invalid_authority_id');
    }
    if (limit < 1 || limit > 200) {
      throw const MetraApiException(400, 'invalid_limit');
    }
    final response = await _send(
      'GET',
      '/api/v1/authorities/${Uri.encodeComponent(authorityId)}/access-audit?limit=$limit',
    );
    return _parseJsonRowList(
        jsonDecode(response.body), 'invalid_authority_access_audit');
  }

  /// GET /api/v1/authorities/{id}/membership-roles
  Future<List<MetraJsonRow>> getAuthorityMembershipRoles(
      String authorityId) async {
    if (authorityId.trim().isEmpty) {
      throw const MetraApiException(400, 'invalid_authority_id');
    }
    final response = await _send(
      'GET',
      '/api/v1/authorities/${Uri.encodeComponent(authorityId)}/membership-roles',
    );
    return _parseJsonRowList(
        jsonDecode(response.body), 'invalid_membership_roles');
  }

  /// GET /api/v1/authorities/{id}/permission-options
  Future<List<MetraJsonRow>> getAuthorityPermissionOptions(
      String authorityId) async {
    if (authorityId.trim().isEmpty) {
      throw const MetraApiException(400, 'invalid_authority_id');
    }
    final response = await _send(
      'GET',
      '/api/v1/authorities/${Uri.encodeComponent(authorityId)}/permission-options',
    );
    return _parseJsonRowList(
        jsonDecode(response.body), 'invalid_permission_options');
  }

  Future<http.Response> _send(String method, String path,
      {Map<String, dynamic>? body}) async {
    if (!isConfigured) throw const MetraApiException(503, 'api_not_configured');
    final token = await accessTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const MetraApiException(401, 'authentication_required');
    }
    final uri = _baseUri!.resolve(path);
    final request = http.Request(method, uri)
      ..headers.addAll(
          {'Accept': 'application/json', 'Authorization': 'Bearer $token'});
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response =
        await http.Response.fromStream(await _client.send(request));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var code = 'request_failed';
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['code'] is String) {
          code = decoded['code'] as String;
        } else if (decoded is Map && decoded['error'] is String) {
          code = decoded['error'] as String;
        }
      } catch (_) {}
      throw MetraApiException(response.statusCode, code);
    }
    return response;
  }

  void close() => _client.close();
}
