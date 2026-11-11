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
          'elevation_m': 412.0,
          'station_coordinates': [{
            'latitude': 24.7,
            'longitude': 46.7,
            'coordinate_source': 'surveyed',
            'accuracy_m': 3.2,
          }]
        }])), 200);
      }));
    final rows = await client.getStationDirectory(stationType: 'classic');
    expect(captured.url.path, '/api/v1/stations');
    expect(captured.url.queryParameters['stationType'], 'classic');
    expect(captured.headers['authorization'], 'Bearer directory-token');
    expect(rows.single.nameArabic, 'محطة اختبار');
    expect(rows.single.hasCoordinates, isTrue);
    expect(rows.single.approvalStatus, 'pending');
    expect(rows.single.elevationM, 412.0);
    expect(rows.single.coordinateSource, 'surveyed');
    expect(rows.single.coordinateAccuracyM, 3.2);
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

  test('hourly submission sends canonical nested values and requires a receipt', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'submission-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({
          'id': '33333333-3333-4333-8333-333333333333',
          'status': 'submitted',
          'replayed': false,
        }), 200);
      }),
    );

    final receipt = await client.submitObservation(
      stationId: stationId,
      idempotencyKey: 'hourly-test-key',
      observationType: 'hourly',
      observedAt: DateTime.utc(2026, 11, 9, 12),
      payload: {
        'values': {
          'utcTime': '12',
          'dryTemp': '+25.0',
          'totalCloudCover': '4',
        },
      },
      submit: true,
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.headers['authorization'], 'Bearer submission-token');
    expect(body['observationType'], 'hourly');
    expect(body['payload']['values']['utcTime'], '12');
    expect(body['payload']['values']['totalCloudCover'], '4');
    expect(body['payload']['cloudCover'], isNull);
    expect(receipt['id'], '33333333-3333-4333-8333-333333333333');
    client.close();
  });

  test('does not treat a 2xx response without an observation id as saved', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'submission-token',
      client: MockClient((_) async => http.Response(
        jsonEncode({'status': 'submitted', 'replayed': false}), 200)),
    );

    await expectLater(
      client.submitObservation(
        stationId: stationId,
        idempotencyKey: 'hourly-no-receipt',
        observationType: 'hourly',
        observedAt: DateTime.utc(2026, 11, 9, 12),
        payload: {'values': {'utcTime': '12'}},
        submit: true,
      ),
      throwsA(isA<FormatException>()),
    );
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
    expect(ApiConfig.isValidUrl('https://api.example.test/api/v1'), isFalse);
    expect(ApiConfig.isValidUrl('https://api.example.test/'), isTrue);
    expect(ApiConfig.isValidUrl('https://api.example.test'), isTrue);
  });


  test('forecasting comparison uses the server contract and parses catalogue pairs', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'forecast-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({
          'source': 'metra_station_catalogue',
          'stations': [
            {'stationId': stationId, 'meteorologicalValues': null},
            {'stationId': '22222222-2222-4222-8222-222222222222', 'meteorologicalValues': null},
          ],
          'pairs': [
            {'fromStationId': stationId, 'toStationId': '22222222-2222-4222-8222-222222222222',
             'distanceKm': 12.4, 'elevationDifferenceM': 80, 'distanceAvailable': true},
          ],
        }), 200);
      }),
    );

    final result = await client.compareForecastingStations([
      stationId, '22222222-2222-4222-8222-222222222222',
    ]);
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/forecasting/compare');
    expect(captured.headers['authorization'], 'Bearer forecast-token');
    expect(jsonDecode(captured.body)['stationIds'], hasLength(2));
    expect(result['pairs'], hasLength(1));
    expect((result['pairs'] as List).single['distanceKm'], 12.4);
    expect((result['stations'] as List).first['meteorologicalValues'], isNull);
    client.close();
  });

  test('forecasting comparison rejects duplicate and out-of-range station counts', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'forecast-token',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await expectLater(
      client.compareForecastingStations([stationId, stationId]),
      throwsA(isA<MetraApiException>().having((e) => e.code, 'code', 'duplicate_station_ids')),
    );
    await expectLater(
      client.compareForecastingStations([stationId]),
      throwsA(isA<MetraApiException>().having((e) => e.code, 'code', 'compare_requires_2_to_12_stations')),
    );
    client.close();
  });

}
