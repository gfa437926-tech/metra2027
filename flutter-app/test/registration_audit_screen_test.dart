import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/admin/registration_audit_screen.dart';

void main() {
  testWidgets('registration audit reads the server audit endpoint and displays UTC actor data',
      (tester) async {
    String? requestedPath;
    final client = MockClient((request) async {
      requestedPath = request.url.path;
      return http.Response.bytes(
        utf8.encode(jsonEncode([
          {
            'id': 1,
            'request_id': '11111111-1111-4111-8111-111111111111',
            'user_id': '22222222-2222-4222-8222-222222222222',
            'actor_user_id': '33333333-3333-4333-8333-333333333333',
            'event_type': 'approved',
            'terms_version': 'metra-terms-2026-11',
            'decision_note': 'تم التحقق من بيانات الطلب',
            'occurred_at': '2026-11-11T10:15:00Z',
          },
        ])),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'registration-audit-token',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(
      home: RegistrationAuditScreen(api: api, stationId: 'station-1'),
    ));
    await tester.pumpAndSettle();

    expect(requestedPath, '/api/v1/stations/station-1/registration-audit');
    expect(find.text('اعتماد'), findsOneWidget);
    expect(find.textContaining('2026-11-11T10:15:00.000Z UTC'), findsOneWidget);
    expect(find.textContaining('تم التحقق من بيانات الطلب'), findsOneWidget);
    expect(find.textContaining('22222222'), findsOneWidget);
    api.close();
  });
}
