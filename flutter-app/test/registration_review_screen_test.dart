import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/admin/registration_review_screen.dart';

void main() {
  testWidgets('registration review resolves request_id and requires a rejection note',
      (tester) async {
    var listReads = 0;
    Map<String, dynamic>? decisionBody;
    String? decisionPath;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/stations/station-1/registration-requests') {
        listReads++;
        return http.Response.bytes(
          utf8.encode(jsonEncode(listReads == 1
              ? [
                  {
                    'request_id': 'request-123',
                    'first_name': 'أحمد',
                    'father_name': 'محمد',
                    'last_name': 'علي',
                    'requested_role_code': 'observer',
                    'status': 'pending_station_approval',
                    'submitted_at': '2026-11-11T10:00:00Z',
                  }
                ]
              : [])),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.method == 'POST' &&
          request.url.path ==
              '/api/v1/stations/station-1/registration-requests/request-123/decision') {
        decisionPath = request.url.path;
        decisionBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }
      return http.Response('not_found', 404);
    });
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'registration-review-token',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(
      home: RegistrationReviewScreen(api: api, stationId: 'station-1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمد علي'), findsOneWidget);
    expect(find.textContaining('observer'), findsOneWidget);
    expect(find.textContaining('2026-11-11T10:00:00.000Z'), findsOneWidget);

    await tester.tap(find.text('رفض'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'بيانات غير مكتملة');
    await tester.tap(find.text('تأكيد الرفض'));
    await tester.pumpAndSettle();

    expect(decisionPath, contains('/request-123/decision'));
    expect(decisionBody?['decision'], 'reject');
    expect(decisionBody?['note'], 'بيانات غير مكتملة');
    expect(find.text('لا طلبات معلّقة في هذه المرحلة لهذه المحطة.'), findsOneWidget);
    api.close();
  });

  testWidgets('registration review switches to the system-stage API queue', (tester) async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      return http.Response('[]', 200);
    });
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'system-review-token',
      client: client,
    );
    await tester.pumpWidget(MaterialApp(
      home: RegistrationReviewScreen(api: api, stationId: 'station-2'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(requestedPaths, contains('/api/v1/stations/station-2/system-registration-requests'));
    api.close();
  });
}
