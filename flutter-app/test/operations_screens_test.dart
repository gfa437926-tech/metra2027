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
  testWidgets('equipment fault form submits validated station-scoped UTC payload', (tester) async {
    final List<http.Request> requests = <http.Request>[];
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'operations-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') return http.Response(jsonEncode(<dynamic>[]), 200);
        return http.Response('{}', 201);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: EquipmentFaultScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'حساس الحرارة',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'قراءة الحساس متوقفة منذ بداية الوردية',
    );
    final send = find.text('إرسال إلى الخادم');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();

    final post = requests.firstWhere((request) => request.method == 'POST');
    final payload = jsonDecode(post.body) as Map<String, dynamic>;
    expect(post.url.path, '/api/v1/stations/$stationId/equipment-faults');
    expect(post.headers['authorization'], 'Bearer operations-token');
    expect(payload['equipmentName'], 'حساس الحرارة');
    expect(payload['description'], 'قراءة الحساس متوقفة منذ بداية الوردية');
    expect(payload['occurredAt'], endsWith('Z'));
    expect(find.text('تم إرسال بلاغ العطل إلى الخادم'), findsOneWidget);
    api.close();
  });

  testWidgets('support form submits station-scoped UTC incident payload', (tester) async {
    final List<http.Request> requests = <http.Request>[];
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'support-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') return http.Response(jsonEncode(<dynamic>[]), 200);
        return http.Response('{}', 201);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: SupportIncidentScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    Future<void> fill(int index, String value) async {
      await tester.enterText(find.byType(TextFormField).at(index), value);
    }
    await fill(0, 'شبكة الاتصالات');
    await fill(1, 'انقطاع الاتصال بالمركز');
    await fill(2, 'تعذر إرسال بيانات المحطة إلى المركز منذ عشر دقائق');
    final send = find.text('إرسال إلى الخادم');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();

    final post = requests.firstWhere((request) => request.method == 'POST');
    final payload = jsonDecode(post.body) as Map<String, dynamic>;
    expect(post.url.path, '/api/v1/stations/$stationId/support-incidents');
    expect(post.headers['authorization'], 'Bearer support-token');
    expect(payload['category'], 'شبكة الاتصالات');
    expect(payload['title'], 'انقطاع الاتصال بالمركز');
    expect(payload['occurredAt'], endsWith('Z'));
    expect(find.text('تم إرسال بلاغ الدعم إلى الخادم'), findsOneWidget);
    api.close();
  });

}
