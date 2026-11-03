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

  test('station directory parses coordinate and approval state', () async {
    late http.Request captured;
    final client = MetraApiClient(baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'directory-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response.bytes(utf8.encode(jsonEncode([{
          'id': stationId, 'local_station_code': 'ST-001',
          'name_ar': 'محطة اختبار', 'name_en': 'Test station',
          'station_type': 'classic', 'operational_status': 'unverified',
          'approval_status': 'pending', 'is_demo': false,
          'station_coordinates': [{'latitude': 24.7, 'longitude': 46.7}]
        }])), 200);
      }));
    final rows = await client.getStationDirectory(stationType: 'classic');
    expect(captured.url.path, '/api/v1/stations');
    expect(captured.url.queryParameters['stationType'], 'classic');
    expect(captured.headers['authorization'], 'Bearer directory-token');
    expect(rows.single.nameArabic, 'محطة اختبار');
    expect(rows.single.hasCoordinates, isTrue);
    expect(rows.single.approvalStatus, 'pending');
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
