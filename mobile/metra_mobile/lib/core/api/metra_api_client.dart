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
    this.latitude, this.longitude, this.wmoStationId});
  final String id, localCode, nameArabic, nameEnglish, stationType;
  final String operationalStatus, approvalStatus;
  final bool isDemo;
  final double? latitude, longitude;
  final String? wmoStationId;
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
    final coords = json['station_coordinates'];
    if (coords is List && coords.isNotEmpty && coords.first is Map) {
      final point = Map<String, dynamic>.from(coords.first as Map);
      lat = number(point['latitude']); lon = number(point['longitude']);
    }
    return StationDirectoryItem(id: json['id'] as String,
      localCode: json['local_station_code'] as String,
      nameArabic: json['name_ar'] as String, nameEnglish: json['name_en'] as String,
      stationType: json['station_type'] as String,
      operationalStatus: json['operational_status'] as String,
      approvalStatus: json['approval_status'] as String, isDemo: json['is_demo'] == true,
      latitude: lat, longitude: lon, wmoStationId: json['wmo_station_id'] as String?);
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


  Future<List<ObservationQueueItem>> getReturnedObservations(String stationId, {int limit = 50}) async {
    final response = await _send(
      'GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations/returned?limit=$limit',
    );
    final decoded = jsonDecode(response.body);
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

  Future<void> submitObservation({required String stationId,
    required String idempotencyKey, required String observationType,
    required DateTime observedAt, required Map<String, dynamic> payload,
    bool submit = false}) async {
    await _send('POST', '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations',
      body: {'idempotencyKey': idempotencyKey, 'observationType': observationType,
        'observedAt': observedAt.toUtc().toIso8601String(),
        'payload': payload, 'submit': submit});
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
