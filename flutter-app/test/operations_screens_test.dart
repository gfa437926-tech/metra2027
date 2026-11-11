import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/maintenance/equipment_fault_screen.dart';
import 'package:metra_mobile/features/support/support_incident_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  testWidgets('equipment fault workspace loads station-scoped queue and form', (tester) async {
    late http.Request captured;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'operations-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(<dynamic>[]), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: EquipmentFaultScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    expect(captured.url.path, '/api/v1/stations/$stationId/equipment-faults');
    expect(captured.headers['authorization'], 'Bearer operations-token');
    expect(find.text('أعطال المعدات'), findsOneWidget);
    expect(find.text('بلاغ عطل جديد'), findsOneWidget);
    expect(find.text('اسم المعدة'), findsOneWidget);
    final emptyFaultState = find.text('لا توجد بلاغات أعطال مسجّلة لهذه المحطة');
    await tester.ensureVisible(emptyFaultState);
    await tester.pumpAndSettle();
    expect(emptyFaultState, findsOneWidget);
    api.close();
  });

  testWidgets('support workspace loads station-scoped queue and incident form', (tester) async {
    late http.Request captured;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'support-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(<dynamic>[]), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: SupportIncidentScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    expect(captured.url.path, '/api/v1/stations/$stationId/support-incidents');
    expect(captured.headers['authorization'], 'Bearer support-token');
    expect(find.text('بلاغات الدعم'), findsOneWidget);
    expect(find.text('العنوان'), findsOneWidget);
    expect(find.text('الوصف'), findsOneWidget);
    final emptySupportState = find.text('لا توجد بلاغات دعم مسجّلة');
    await tester.ensureVisible(emptySupportState);
    await tester.pumpAndSettle();
    expect(emptySupportState, findsOneWidget);
    api.close();
  });
}
