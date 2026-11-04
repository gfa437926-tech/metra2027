import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/api_config.dart';

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


  test('station coordinates distinguish missing, valid and out-of-range values', () {
    StationDirectoryItem station(double? latitude, double? longitude) => StationDirectoryItem(
      id: stationId, localCode: 'ST-001', nameArabic: 'اختبار', nameEnglish: 'Test',
      stationType: 'classic', operationalStatus: 'unverified', approvalStatus: 'pending',
      isDemo: false, latitude: latitude, longitude: longitude);
    expect(station(24.7, 46.7).hasValidCoordinates, isTrue);
    expect(station(null, 46.7).hasValidCoordinates, isFalse);
    expect(station(91, 46.7).hasValidCoordinates, isFalse);
    expect(station(24.7, -181).hasValidCoordinates, isFalse);
  });

  test('station directory fetches every page instead of silently hiding stations', () async {
    var requests = 0;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'directory-token',
      client: MockClient((request) async {
        requests++;
        final offset = int.parse(request.url.queryParameters['offset']!);
        final count = offset == 0 ? 500 : 1;
        final rows = List.generate(count, (index) {
          final n = offset + index;
          return {
            'id': 'station-$n',
            'local_station_code': 'ST-$n',
            'name_ar': 'Station $n',
            'name_en': 'Station $n',
            'station_type': 'classic',
            'operational_status': 'unverified',
            'approval_status': 'pending',
            'is_demo': false,
            'station_coordinates': <Map<String, dynamic>>[],
          };
        });
        return http.Response(jsonEncode(rows), 200);
      }),
    );
    final rows = await client.getAllStationDirectory(stationType: 'classic');
    expect(requests, 2);
    expect(rows, hasLength(501));
    expect(rows.last.localCode, 'ST-500');
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
  test('API is not configured when the build-time URL is missing', () {
    final client = MetraApiClient(
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    expect(client.isConfigured, isFalse);
    expect(ApiConfig.isConfigured, isFalse);
    client.close();
  });

  test('rejects API URLs containing credentials, query or fragment', () {
    expect(ApiConfig.isValidUrl('https://user:secret@api.example.test'), isFalse);
    expect(ApiConfig.isValidUrl('https://api.example.test?token=secret'), isFalse);
    expect(ApiConfig.isValidUrl('https://api.example.test#section'), isFalse);
    expect(ApiConfig.isValidUrl('https://api.example.test'), isTrue);
  });

}
