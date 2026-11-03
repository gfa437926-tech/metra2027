import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';
  test('review queue authenticates and parses API rows', () async {
    late http.Request captured;
    final client = MetraApiClient(baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'test-access-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode([{
          'id': '22222222-2222-4222-8222-222222222222',
          'station_id': stationId, 'observation_type': 'daily',
          'observed_at': '2026-11-03T12:00:00Z', 'status': 'submitted',
          'payload': {'temperature': 28}
        }]), 200);
      }));
    final rows = await client.getReviewQueue(stationId);
    expect(captured.headers['authorization'], 'Bearer test-access-token');
    expect(rows, hasLength(1));
    expect(rows.single.payload['temperature'], 28);
    client.close();
  });

  test('requires access token', () async {
    final client = MetraApiClient(baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => null,
      client: MockClient((_) async => http.Response('[]', 200)));
    await expectLater(client.getReviewQueue(stationId),
      throwsA(isA<MetraApiException>().having((e) => e.statusCode, 'statusCode', 401)));
    client.close();
  });

  test('requires HTTPS API origin', () async {
    final client = MetraApiClient(baseUrl: 'http://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('[]', 200)));
    await expectLater(client.getReviewQueue(stationId),
      throwsA(isA<MetraApiException>().having((e) => e.code, 'code', 'api_not_configured')));
    client.close();
  });

  test('bounds queue limit', () async {
    final client = MetraApiClient(baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('[]', 200)));
    await expectLater(client.getReviewQueue(stationId, limit: 101),
      throwsA(isA<MetraApiException>().having((e) => e.code, 'code', 'invalid_limit')));
    client.close();
  });
}
