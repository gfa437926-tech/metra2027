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
      client: MockClient((request) async => http.Response(
        jsonEncode({
          'isValid': false,
          'issues': [
            {'field': 'stationPressure', 'message': 'ضغط المحطة خارج المجال.'}
          ]
        }),
        200,
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

    expect(
      () => client.validateHourly({'utcTime': '00'}),
      throwsA(isA<http.ClientException>()),
    );
    client.close();
  });
}
