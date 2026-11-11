import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/admin/station_audit_log_screen.dart';

void main() {
  testWidgets('station audit log displays server actor, target and UTC event details',
      (tester) async {
    String? path;
    final client = MockClient((request) async {
      path = request.url.path;
      return http.Response.bytes(
        utf8.encode(jsonEncode([
          {
            'entity_type': 'station_user_assignment',
            'action': 'assignment_revoked',
            'actor_id': '11111111-1111-4111-8111-111111111111',
            'target_user_id': '22222222-2222-4222-8222-222222222222',
            'role_code': 'station_auditor',
            'previous_status': 'active',
            'resulting_status': 'revoked',
            'valid_from': '2026-11-01T00:00:00Z',
            'valid_to': '2026-12-01T00:00:00Z',
            'reason': 'انتهاء الحاجة التشغيلية',
            'occurred_at': '2026-11-11T10:15:00Z',
          },
        ])),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'station-audit-token',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(
      home: StationAuditLogScreen(api: api, stationId: 'station-1'),
    ));
    await tester.pumpAndSettle();

    expect(path, '/api/v1/stations/station-1/audit-log');
    expect(find.textContaining('assignment_revoked'), findsOneWidget);
    expect(find.textContaining('station_auditor'), findsOneWidget);
    expect(find.textContaining('2026-11-11T10:15:00.000Z UTC'), findsOneWidget);
    expect(find.textContaining('انتهاء الحاجة التشغيلية'), findsOneWidget);
    api.close();
  });
}
