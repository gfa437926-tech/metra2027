import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';

void main() {
  test('hourly validation sends legacy fixed-width numeric values', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'validation-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'isValid': true, 'issues': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.validateObservation(
      observationType: 'hourly',
      values: {
        'utcTime': '07',
        'dryTemp': 18,
        'wetTemp': 12,
        'stationPressure': 1000,
        'seaLevelPressure': 1012,
        'relativeHumidity': 65,
        'dewPoint': 8,
        'windDirection': 4,
        'windSpeed': 5,
        'visibility': 10,
        'currentWeather': 0,
        'pastWeather': 0,
        'totalCloudCover': '4',
        'cover12': 3,
        'cover123': 4,
      },
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    final values = body['values'] as Map<String, dynamic>;
    expect(captured.url.path, '/api/v1/observations/hourly/validate');
    expect(captured.headers['authorization'], 'Bearer validation-token');
    expect(values['dryTemp'], '+18.0');
    expect(values['wetTemp'], '+12.0');
    expect(values['stationPressure'], '1000.0');
    expect(values['relativeHumidity'], '065');
    expect(values['visibility'], '010');
    expect(values['windSpeed'], '05');
    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
    client.close();
  });

  test('daily validation preserves values with unsupported precision', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'validation-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'isValid': false,
            'issues': [
              {'field': 'minTemp', 'message': 'تنسيق غير صالح'}
            ]
          })),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.validateObservation(
      observationType: 'daily',
      values: {'minTemp': -2.25, 'maxTemp': 18},
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    final values = body['values'] as Map<String, dynamic>;
    expect(captured.url.path, '/api/v1/observations/daily/validate');
    expect(values['minTemp'], '-2.25');
    expect(values['maxTemp'], '18.0');
    expect(result.isValid, isFalse);
    expect(result.issues.single.field, 'minTemp');
    client.close();
  });
}
