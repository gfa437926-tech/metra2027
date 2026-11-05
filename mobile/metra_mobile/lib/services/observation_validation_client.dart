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

  void close() => _client.close();
}
