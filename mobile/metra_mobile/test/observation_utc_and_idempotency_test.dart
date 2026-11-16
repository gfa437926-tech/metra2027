import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  test('converts offset local time to UTC ISO-8601 on submit', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{}', 201);
      }),
    );

    // +03:00 offset (e.g. Damascus standard) -> UTC is 3 hours earlier.
    final localWithOffset = DateTime.parse('2026-07-15T14:00:00+03:00');
    await client.submitObservation(
      stationId: stationId,
      idempotencyKey: 'tz-key-1',
      observationType: 'hourly',
      observedAt: localWithOffset,
      payload: const {'dryTemp': 30},
      submit: true,
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['observedAt'], '2026-07-15T11:00:00.000Z');
    client.close();
  });

  test('winter offset (+02:00) also converts correctly to UTC', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{}', 201);
      }),
    );

    final winter = DateTime.parse('2026-01-10T09:30:00+02:00');
    await client.submitObservation(
      stationId: stationId,
      idempotencyKey: 'tz-winter-1',
      observationType: 'daily',
      observedAt: winter,
      payload: const {'minTemp': 5},
      submit: true,
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['observedAt'], '2026-01-10T07:30:00.000Z');
    client.close();
  });

  test('already-UTC DateTime is sent unchanged in Z form', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{}', 201);
      }),
    );

    final utc = DateTime.utc(2026, 11, 16, 12, 0, 0);
    await client.submitObservation(
      stationId: stationId,
      idempotencyKey: 'utc-key-1',
      observationType: 'hourly',
      observedAt: utc,
      payload: const {'dryTemp': 18},
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['observedAt'], '2026-11-16T12:00:00.000Z');
    client.close();
  });

  test('same idempotency key can be resent without client-side rejection', () async {
    var requests = 0;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        requests++;
        return http.Response('{}', 201);
      }),
    );

    const key = 'stable-idempotency-key';
    final observedAt = DateTime.utc(2026, 11, 16, 8, 0);
    for (var i = 0; i < 3; i++) {
      await client.submitObservation(
        stationId: stationId,
        idempotencyKey: key,
        observationType: 'hourly',
        observedAt: observedAt,
        payload: const {'dryTemp': 20},
        submit: true,
      );
    }
    // Client allows retries; server is responsible for deduplication.
    expect(requests, 3);
    client.close();
  });

  test('network failure surfaces Arabic network_unavailable message', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async {
        throw http.ClientException('Connection failed');
      }),
    );

    try {
      await client.getReviewQueue(stationId);
      fail('expected MetraApiException');
    } on MetraApiException catch (error) {
      expect(error.code, 'network_unavailable');
      expect(error.displayMessage, contains('الشبكة'));
      expect(error.displayMessage, isNot(contains('ClientException')));
    }
    client.close();
  });

  test('401 response maps to session/auth Arabic message', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'expired-token',
      client: MockClient((_) async => http.Response('{"error":"unauthorized"}', 401)),
    );

    try {
      await client.getReviewQueue(stationId);
      fail('expected MetraApiException');
    } on MetraApiException catch (error) {
      expect(error.statusCode, 401);
      expect(error.displayMessage, anyOf(contains('الجلسة'), contains('الدخول')));
      expect(error.displayMessage, isNot(contains('unauthorized')));
    }
    client.close();
  });
}
