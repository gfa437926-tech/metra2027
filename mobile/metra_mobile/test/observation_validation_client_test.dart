import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/services/observation_validation_client.dart';

void main() {
  test('posts hourly values to the .NET validation endpoint', () async {
    final client = ObservationValidationClient(
      baseUrl: 'https://api.example.test/api/v1/',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/observations/hourly/validate',
        );
        expect(request.headers['content-type'], contains('application/json'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect((body['values'] as Map<String, dynamic>)['utcTime'], '06');
        return http.Response(
          jsonEncode({'isValid': true, 'issues': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.validateHourly({
      'utcTime': '06',
      'dryTemp': '+21.0',
      'wetTemp': '+18.0',
    });

    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
    client.close();
  });

  test('returns server validation issues to the mobile caller', () async {
    final client = ObservationValidationClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async => http.Response.bytes(
        utf8.encode(jsonEncode({
          'isValid': false,
          'issues': [
            {'field': 'stationPressure', 'message': 'ضغط المحطة خارج المجال.'}
          ]
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      )),
    );

    final result = await client.validateHourly({'utcTime': '12'});

    expect(result.isValid, isFalse);
    expect(result.issues, hasLength(1));
    expect(result.issues.single.field, 'stationPressure');
    expect(result.issues.single.message, 'ضغط المحطة خارج المجال.');
    client.close();
  });

  test('rejects non-success HTTP responses', () async {
    final client = ObservationValidationClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async => http.Response('Unavailable', 503)),
    );

    await expectLater(
      client.validateHourly({'utcTime': '00'}),
      throwsA(isA<http.ClientException>()),
    );
    client.close();
  });

  test('rejects malformed response payloads', () async {
    final client = ObservationValidationClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async => http.Response('[]', 200)),
    );

    await expectLater(
      client.validateHourly({'utcTime': '00'}),
      throwsA(isA<FormatException>()),
    );
    client.close();
  });


  test('submits an hourly observation with bearer authorization and UTC metadata', () async {
    final client = ObservationValidationClient(
      baseUrl: 'https://api.example.test/api/v1/',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/observations/hourly');
        expect(request.headers['authorization'], 'Bearer test-access-token');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['observationDate'], '2026-11-06');
        expect(payload['utcHour'], 6);
        expect((payload['values'] as Map<String, dynamic>)['utcTime'], '06');
        return http.Response(
          jsonEncode({
            'observationId': 'obs-123',
            'stationId': 'station-7',
            'status': 0,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.submitHourly(
      accessToken: 'test-access-token',
      observationDate: DateTime(2026, 11, 6),
      utcHour: 6,
      values: {'utcTime': '06', 'dryTemp': '+21.0'},
    );

    expect(result['observationId'], 'obs-123');
    expect(result['stationId'], 'station-7');
    client.close();
  });

  test('rejects empty access tokens before making a request', () async {
    final client = ObservationValidationClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async => http.Response('{}', 201)),
    );

    await expectLater(
      client.submitHourly(
        accessToken: '  ',
        observationDate: DateTime(2026, 11, 6),
        utcHour: 0,
        values: {'utcTime': '00'},
      ),
      throwsArgumentError,
    );
    client.close();
  });

  test('rejects invalid UTC hours before making a request', () async {
    final client = ObservationValidationClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async => http.Response('{}', 201)),
    );

    await expectLater(
      client.submitHourly(
        accessToken: 'test-access-token',
        observationDate: DateTime(2026, 11, 6),
        utcHour: 24,
        values: {'utcTime': '24'},
      ),
      throwsArgumentError,
    );
    client.close();
  });
  test('rejects conflicting UTC hour metadata before making a request', () async {
    var requests = 0;
    final client = ObservationValidationClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async {
        requests++;
        return http.Response('{}', 201);
      }),
    );

    await expectLater(
      client.submitHourly(
        accessToken: 'test-access-token',
        observationDate: DateTime(2026, 11, 6),
        utcHour: 6,
        values: {'utcTime': '09'},
      ),
      throwsArgumentError,
    );

    expect(requests, 0);
    client.close();
  });

  test('rejects conflicting observation date metadata before making a request', () async {
    var requests = 0;
    final client = ObservationValidationClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async {
        requests++;
        return http.Response('{}', 201);
      }),
    );

    await expectLater(
      client.submitHourly(
        accessToken: 'test-access-token',
        observationDate: DateTime(2026, 11, 6),
        utcHour: 6,
        values: {'observationDate': '2026-11-07'},
      ),
      throwsArgumentError,
    );

    expect(requests, 0);
    client.close();
  });



  test('rejects empty identifiers in successful submission responses', () async {
    final client = ObservationValidationClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async => http.Response(
        jsonEncode({
          'observationId': '   ',
          'stationId': 'station-7',
          'status': 0,
        }),
        201,
      )),
    );

    await expectLater(
      client.submitHourly(
        accessToken: 'test-access-token',
        observationDate: DateTime(2026, 11, 6),
        utcHour: 6,
        values: {'utcTime': '06'},
      ),
      throwsA(isA<FormatException>()),
    );
    client.close();
  });

  test('rejects structured status values in successful submission responses', () async {
    final client = ObservationValidationClient(
      baseUrl: 'https://api.example.test/api/v1',
      client: MockClient((request) async => http.Response(
        jsonEncode({
          'observationId': 'obs-123',
          'stationId': 'station-7',
          'status': {'state': 'accepted'},
        }),
        201,
      )),
    );

    await expectLater(
      client.submitHourly(
        accessToken: 'test-access-token',
        observationDate: DateTime(2026, 11, 6),
        utcHour: 6,
        values: {'utcTime': '06'},
      ),
      throwsA(isA<FormatException>()),
    );
    client.close();
  });

}
