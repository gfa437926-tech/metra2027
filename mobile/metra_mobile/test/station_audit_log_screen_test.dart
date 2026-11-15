import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/stations/station_audit_log_screen.dart';

void main() {
  testWidgets('station audit screen displays immutable station history from the API', (tester) async {
    const stationId = '11111111-1111-4111-8111-111111111111';
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'audit-token',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/stations/$stationId/audit-log');
        return http.Response.bytes(
          utf8.encode(jsonEncode([
            {
              'id': '33333333-3333-4333-8333-333333333333',
              'entity_type': 'station_assignment',
              'entity_id': stationId,
              'action': 'update',
              'actor_id': '44444444-4444-4444-8444-444444444444',
              'reason': 'تحديث تعيين',
              'occurred_at': '2026-11-11T12:00:00Z',
              'target_user_id': '55555555-5555-4555-8555-555555555555',
              'role_code': 'station_observer',
              'previous_status': 'pending',
              'resulting_status': 'approved',
              'valid_from': '2026-11-11T00:00:00Z',
              'valid_to': null,
            },
          ])),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StationAuditLogScreen(
            api: api,
            stationId: stationId,
            stationName: 'محطة الاختبار',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('سجل تدقيق المحطة'), findsOneWidget);
    expect(find.text('محطة الاختبار'), findsOneWidget);
    expect(find.text('تحديث سجل'), findsOneWidget);
    expect(find.text('تعيين محطة'), findsOneWidget);
    expect(find.text('pending → approved'), findsOneWidget);
    expect(find.text('تحديث تعيين'), findsOneWidget);
    expect(find.textContaining('لا يمثل هذا أرشيف النشرات'), findsOneWidget);

    api.close();
  });

  testWidgets('station audit screen shows a permission-specific denial message', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'audit-token',
      client: MockClient((_) async => http.Response('{"error":"forbidden"}', 403)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StationAuditLogScreen(
            api: api,
            stationId: '11111111-1111-4111-8111-111111111111',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('لا تملك صلاحية عرض سجل هذه المحطة.'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    api.close();
  });
}
