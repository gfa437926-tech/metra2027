import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  test('validateObservation phenomenon posts WeatherPhenomenonRequest body', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'isValid': true,
            'issues': <Map<String, String>>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.validateObservation(
      observationType: 'phenomenon',
      values: {
        'phenomenonType': 'fog',
        'phenomenonDate': '2026-11-16',
        'startTime': '06:00:00',
        'endTime': null,
        'generalNotes': 'ضباب',
      },
    );

    expect(result.isValid, isTrue);
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/observations/phenomena/validate');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['phenomenonType'], 'fog');
    expect(body['phenomenonDate'], '2026-11-16');
    expect(body['startTime'], '06:00:00');
    expect(body.containsKey('values'), isFalse);
    client.close();
  });

  test('submitObservation accepts phenomenon type with UTC observedAt', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{}', 201);
      }),
    );

    await client.submitObservation(
      stationId: stationId,
      idempotencyKey: 'phenomenon-key-1',
      observationType: 'phenomenon',
      observedAt: DateTime.parse('2026-11-16T09:30:00+03:00'),
      payload: {
        'phenomenonType': 'rain',
        'phenomenonDate': '2026-11-16',
        'startTime': '06:00:00',
        'responsibilityAgreement': true,
      },
      submit: true,
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['observationType'], 'phenomenon');
    expect(body['idempotencyKey'], 'phenomenon-key-1');
    expect(body['observedAt'], '2026-11-16T06:30:00.000Z');
    expect(body['submit'], isTrue);
    client.close();
  });

  test('failed validation does not claim success', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'isValid': false,
            'issues': [
              {'field': 'start_time', 'message': 'وقت البدء يجب أن يكون بالتنسيق HH:mm:ss بتوقيت UTC.'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.validateObservation(
      observationType: 'phenomenon',
      values: {'phenomenonType': 'fog'},
    );
    expect(result.isValid, isFalse);
    expect(result.issues, isNotEmpty);
    expect(result.issues.first.message, contains('HH:mm:ss'));
    client.close();
  });

  test('401 maps to Arabic session message without technical leakage', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'expired',
      client: MockClient((_) async => http.Response('unauthorized', 401)),
    );

    try {
      await client.submitObservation(
        stationId: stationId,
        idempotencyKey: 'k',
        observationType: 'phenomenon',
        observedAt: DateTime.utc(2026, 11, 16),
        payload: const {'phenomenonType': 'fog'},
      );
      fail('expected exception');
    } on MetraApiException catch (error) {
      expect(error.statusCode, 401);
      expect(error.displayMessage, isNot(contains('unauthorized')));
      expect(
        error.displayMessage,
        anyOf(contains('الجلسة'), contains('صلاحية'), contains('الدخول')),
      );
    }
    client.close();
  });

  test('403 and 409 display Arabic operator messages', () async {
    for (final status in [403, 409]) {
      final client = MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'token',
        client: MockClient((_) async => http.Response('{}', status)),
      );
      try {
        await client.submitObservation(
          stationId: stationId,
          idempotencyKey: 'k-$status',
          observationType: 'phenomenon',
          observedAt: DateTime.utc(2026, 11, 16),
          payload: const {'phenomenonType': 'fog'},
        );
        fail('expected exception');
      } on MetraApiException catch (error) {
        expect(error.statusCode, status);
        expect(error.displayMessage, isNot(contains('Exception')));
        expect(error.displayMessage.isNotEmpty, isTrue);
      }
      client.close();
    }
  });

  test('same idempotency key may be retried by client', () async {
    var count = 0;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async {
        count++;
        return http.Response('{}', 201);
      }),
    );
    const key = 'stable-phenomenon-key';
    final at = DateTime.utc(2026, 11, 16, 7);
    for (var i = 0; i < 2; i++) {
      await client.submitObservation(
        stationId: stationId,
        idempotencyKey: key,
        observationType: 'phenomenon',
        observedAt: at,
        payload: const {
          'phenomenonType': 'fog',
          'phenomenonDate': '2026-11-16',
          'startTime': '07:00:00',
          'responsibilityAgreement': true,
        },
        submit: true,
      );
    }
    expect(count, 2);
    client.close();
  });
}
