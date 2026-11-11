import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/ai/ai_workspace_screen.dart';
import 'package:metra_mobile/features/climatol/climatol_workspace_screen.dart';

void main() {
  testWidgets('AI workspace exposes governed analysis areas without fabricated results',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiWorkspaceScreen()));
    expect(find.text('مساحة الذكاء الاصطناعي'), findsOneWidget);
    expect(find.text('مسارات العمل'), findsOneWidget);
    await tester.tap(find.text('التحليل'));
    await tester.pumpAndSettle();
    expect(find.text('إعداد طلب التحليل'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('تنفيذ التحليل غير متاح حتى ربط AI Gateway'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('تنفيذ التحليل غير متاح حتى ربط AI Gateway'), findsOneWidget);
    expect(find.textContaining('لم يتم إرسال السؤال'), findsOneWidget);
    await tester.tap(find.text('حوكمة'));
    await tester.pumpAndSettle();
    expect(find.text('حوكمة الذكاء الاصطناعي'), findsOneWidget);
  });

  testWidgets('Climatol workspace loads approved station catalogue and keeps execution gated',
      (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/v1/stations') {
        return http.Response.bytes(
          utf8.encode(jsonEncode([
            {
              'id': '11111111-1111-4111-8111-111111111111',
              'local_station_code': 'N-01',
              'name_ar': 'محطة الشمال',
              'name_en': 'North station',
              'station_type': 'classic',
              'operational_status': 'active',
              'approval_status': 'approved',
              'is_demo': false,
              'elevation_m': 120,
              'station_coordinates': [],
            },
          ])),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not_found', 404);
    });
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'climatol-test-token',
      client: client,
    );
    await tester.pumpWidget(MaterialApp(home: ClimatolWorkspaceScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('تجانس السلاسل المناخية — Climatol'), findsOneWidget);
    expect(find.text('محطة الشمال'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('تشغيل التجانس غير متاح'), 400, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('تشغيل التجانس غير متاح'), findsOneWidget);
    await tester.tap(find.text('التشخيص'));
    await tester.pumpAndSettle();
    expect(find.text('لوحة التشخيص'), findsOneWidget);
    expect(find.text('لا توجد نتائج تشخيص'), findsOneWidget);
    api.close();
  });
}
