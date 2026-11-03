import 'dart:convert';
import 'package:http/http.dart' as http;

const metraApiBaseUrl = String.fromEnvironment('METRA_API_BASE_URL');

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

/// API wrapper. Supply a current Supabase access token from the auth layer.
class MetraApiClient {
  MetraApiClient({required this.accessTokenProvider,
    String baseUrl = metraApiBaseUrl, http.Client? client})
      : _baseUri = Uri.tryParse(baseUrl.trim()), _client = client ?? http.Client();

  final Future<String?> Function() accessTokenProvider;
  final Uri? _baseUri;
  final http.Client _client;
  bool get isConfigured => _baseUri != null &&
      _baseUri!.scheme == 'https' && _baseUri!.host.isNotEmpty;

  Future<List<ObservationQueueItem>> getReviewQueue(String stationId, {int limit = 50}) async {
    if (limit < 1 || limit > 100) throw const MetraApiException(400, 'invalid_limit');
    final response = await _send('GET',
      '/api/v1/stations/${Uri.encodeComponent(stationId)}/observations?limit=$limit');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const FormatException('invalid_observation_queue');
    return decoded.map((item) => ObservationQueueItem.fromJson(
      Map<String, dynamic>.from(item as Map))).toList(growable: false);
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
    final uri = _baseUri!.replace(path:
      '${_baseUri!.path.replaceFirst(RegExp(r'/+$'), '')}$path', query: null);
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
