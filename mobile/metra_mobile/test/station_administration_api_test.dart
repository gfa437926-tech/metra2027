import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';

void main() {
  test('station users are fetched only through the station-scoped endpoint', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'station-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode([
          {'user_id': 'u-1', 'role_code': 'observer'}
        ]), 200);
      }),
    );
    final users = await client.getStationUsers('station-uuid');
    expect(captured.url.path, '/api/v1/stations/station-uuid/users');
    expect(captured.headers['authorization'], 'Bearer station-token');
    expect(users.single['role_code'], 'observer');
    client.close();
  });

  test('station registration decision uses the approved endpoint contract', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'station-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      }),
    );
    await client.decideStationRegistrationRequest(
      stationId: 'station-uuid',
      requestId: 'request-uuid',
      decision: 'reject',
      note: 'بيانات غير مكتملة',
    );
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/stations/station-uuid/registration-requests/request-uuid/decision');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['decision'], 'reject');
    expect(body['note'], 'بيانات غير مكتملة');
    client.close();
  });
}
