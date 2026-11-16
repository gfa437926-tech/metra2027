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

class MetraValidationIssue {
  const MetraValidationIssue({required this.field, required this.message});
  final String field;
  final String message;
}

class MetraObservationValidation {
  const MetraObservationValidation({required this.isValid, required this.issues});
  final bool isValid;
  final List<MetraValidationIssue> issues;
}

class ObservationQueueItem {
  const ObservationQueueItem({required this.id, required this.stationId,
    required this.observationType, required this.observedAt,
    required this.status, this.payload = const {}});
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
    if (id is! String || stationId is! String || type is! String || observedAt == null) {
      throw const FormatException('invalid_observation_queue_item');
    }
    final rawPayload = json['payload'];
    return ObservationQueueItem(id: id, stationId: stationId,
      observationType: type, observedAt: observedAt,
      status: json['status'] is String ? json['status'] as String : 'submitted',
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
          ? point!['coordinate_source'] as String : null,
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

  Future<MetraObservationValidation> validateObservation({
    required String observationType,
    required Map<String, Object?> values,
  }) async {
    final route = switch (observationType) {
      'hourly' => '/api/v1/observations/hourly/validate',
      'daily' => '/api/v1/observations/daily/validate',
      _ => throw const MetraApiException(400, 'unsupported_observation_validation'),
    };
    final normalized = <String, String?>{
      for (final entry in values.entries)
        entry.key: _formatValidationValue(observationType, entry.key, entry.value),
    };
    final response = await _send('POST', route, body: {'values': normalized});
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('invalid_observation_validation_response');
    }
    final rawIssues = decoded['issues'];
    final issues = rawIssues is List
        ? rawIssues.whereType<Map>().map((item) => MetraValidationIssue(
              field: item['field']?.toString() ?? '',
              message: item['message']?.toString() ?? 'قيمة غير صالحة',
            )).toList(growable: false)
        : const <MetraValidationIssue>[];
    return MetraObservationValidation(
      isValid: decoded['isValid'] == true,
      issues: issues,
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
      final sign = negative ? '-' : ((explicitPositiveSign || positive) ? '+' : '');
      return <String>[sign, whole.toString().padLeft(width, '0'), '.', fraction].join();
    }

    if (type == 'hourly') {
      if (const {'dryTemp', 'wetTemp', 'dewPoint'}.contains(field)) return decimal(2, explicitPositiveSign: true);
      if (const {'stationPressure', 'seaLevelPressure'}.contains(field)) return decimal(4);
      if (field == 'relativeHumidity' || field == 'visibility') return integer(3);
      if (const {'windDirection', 'avgWindDirection', 'windSpeed', 'avgWindSpeed'}.contains(field)) return integer(2);
      if (field == 'currentWeather') return integer(2);
      if (const {'pastWeather', 'totalCloudCover', 'cloud1Amount', 'cloud2Amount', 'cloud3Amount', 'cloud4Amount', 'cover12', 'cover123', 'pressureShape'}.contains(field)) return integer(1);
      if (field == 'pressureSlope') return decimal(1);
      if (field == 'vaporPressure' || field == 'vaporPressureDiff') return decimal(2);
      if (field == 'precipitationAmount') return decimal(3);
    }

    if (type == 'daily') {
      if (field == 'minTemp' || field == 'maxTemp') return decimal(2);
      if (field == 'precipitation') return decimal(3);
      if (field == 'snowThickness' || field == 'sunshinePercentage' || field == 'maxHumidity') return integer(3);
      if (field == 'evaporation' || field == 'sunshineDuration' || field == 'maxGustTime' || field == 'maxHumidityTime' || field == 'minHumidityTime') return decimal(2);
      if (field == 'maxGustSpeed' || field == 'maxGustDirection' || field == 'minHumidity') return integer(2);
    }
    return raw;
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
