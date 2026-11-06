import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/observation_validation.dart';

/// Calls the deterministic .NET validation endpoint. This endpoint validates
/// payloads only; it does not save observations or establish authorization.
class ObservationValidationClient {
  ObservationValidationClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<ObservationValidationResult> validateHourly(
    Map<String, String?> values,
  ) async {
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final response = await _client
        .post(
          Uri.parse('$base/observations/hourly/validate'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'values': values}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Hourly validation failed with HTTP ${response.statusCode}.',
        Uri.parse('$base/observations/hourly/validate'),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid validation response.');
    }
    return ObservationValidationResult.fromJson(decoded);
  }


  /// Submits a validated hourly observation to the authenticated workflow.
  /// The access token must come from the configured identity provider.
  Future<Map<String, dynamic>> submitHourly({
    required String accessToken,
    required DateTime observationDate,
    required int utcHour,
    required Map<String, String?> values,
  }) async {
    final token = accessToken.trim();
    if (token.isEmpty) {
      throw ArgumentError.value(accessToken, 'accessToken', 'A bearer token is required.');
    }
    if (utcHour < 0 || utcHour > 23) {
      throw ArgumentError.value(utcHour, 'utcHour', 'UTC hour must be between 0 and 23.');
    }
    final normalizedHour = utcHour.toString().padLeft(2, '0');
    final normalizedDate =
        '${observationDate.year.toString().padLeft(4, '0')}-${observationDate.month.toString().padLeft(2, '0')}-${observationDate.day.toString().padLeft(2, '0')}';
    final payloadHour = values['utcTime'];
    if (payloadHour != null && payloadHour != normalizedHour) {
      throw ArgumentError.value(
        payloadHour,
        'values.utcTime',
        'UTC hour metadata must match utcHour.',
      );
    }
    final payloadDate = values['observationDate'];
    if (payloadDate != null && payloadDate != normalizedDate) {
      throw ArgumentError.value(
        payloadDate,
        'values.observationDate',
        'Observation date metadata must match observationDate.',
      );
    }

    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final response = await _client
        .post(
          Uri.parse('$base/observations/hourly'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'observationDate': normalizedDate,
            'utcHour': utcHour,
            'values': values,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 201) {
      throw http.ClientException(
        'Hourly submission failed with HTTP ${response.statusCode}.',
        Uri.parse('$base/observations/hourly'),
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid hourly submission response.');
    }
    final observationId = decoded['observationId'];
    final stationId = decoded['stationId'];
    final status = decoded['status'];
    final hasValidStatus = status is int ||
        (status is String && status.trim().isNotEmpty);
    if (observationId is! String ||
        observationId.trim().isEmpty ||
        stationId is! String ||
        stationId.trim().isEmpty ||
        !hasValidStatus) {
      throw const FormatException('Invalid hourly submission response.');
    }
    return Map.unmodifiable(decoded);
  }

  void close() => _client.close();
}
