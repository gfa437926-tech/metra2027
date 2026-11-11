import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/auth/registration_screen.dart';

void main() {
  testWidgets('registration loads approved stations and requestable roles, then submits a pending request',
      (tester) async {
    var submitted = false;
    var statusReads = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/stations') {
        return http.Response(jsonEncode([
          {
            'id': '11111111-1111-4111-8111-111111111111',
            'local_station_code': 'ST-01',
            'name_ar': 'محطة معتمدة',
            'name_en': 'Approved station',
            'station_type': 'classic',
            'operational_status': 'active',
            'approval_status': 'approved',
            'is_demo': false,
            'station_coordinates': [],
          },
          {
            'id': '22222222-2222-4222-8222-222222222222',
            'local_station_code': 'ST-02',
            'name_ar': 'محطة تجريبية',
            'name_en': 'Demo station',
            'station_type': 'classic',
            'operational_status': 'active',
            'approval_status': 'approved',
            'is_demo': true,
            'station_coordinates': [],
          },
        ]), 200);
      }
      if (request.url.path == '/api/v1/registration-roles') {
        return http.Response(jsonEncode([
          {'role_code': 'observer', 'name_ar': 'راصد', 'name_en': 'Observer'},
        ]), 200);
      }
      if (request.url.path == '/api/v1/account/registration-status') {
        statusReads++;
        return http.Response(jsonEncode(statusReads == 1
            ? {'account_state': null}
            : {
                'account_state': 'pending_station_approval',
                'state_reason': null,
                'request_id': 'request-1',
                'request_status': 'pending',
                'submitted_at': '2026-11-11T12:00:00Z',
                'review_note': null,
              }), 200);
      }
      if (request.url.path == '/api/v1/registration-requests' && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['stationId'], '11111111-1111-4111-8111-111111111111');
        expect(body['roleCode'], 'observer');
        expect(body['termsVersion'], 'metra-terms-2026-11');
        expect((body['idempotencyKey'] as String).length, greaterThan(20));
        submitted = true;
        return http.Response(jsonEncode({'result_status': 'created'}), 201);
      }
      return http.Response('not_found', 404);
    });
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'registration-test-token',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(
      home: MetraRegistrationScreen(api: api, initiallyAuthenticated: true),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'الاسم الأول'), 'أحمد');
    await tester.enterText(find.widgetWithText(TextField, 'اسم الأب'), 'محمد');
    await tester.enterText(find.widgetWithText(TextField, 'اسم العائلة'), 'علي');

    await tester.tap(find.text('المحطة المطلوبة'));
    await tester.pumpAndSettle();
    expect(find.text('محطة معتمدة — ST-01'), findsOneWidget);
    expect(find.text('محطة تجريبية — ST-02'), findsNothing);
    await tester.tap(find.text('محطة معتمدة — ST-01').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('الدور المطلوب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('راصد').last);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('أقر بصحة البيانات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إرسال طلب الانضمام'));
    await tester.pumpAndSettle();

    expect(submitted, isTrue);
    expect(find.text('بانتظار اعتماد رئيس المحطة'), findsOneWidget);
    expect(find.textContaining('لن تُفعّل الصلاحيات'), findsOneWidget);
    api.close();
  });

  testWidgets('anonymous registration explains email confirmation without claiming METRA activation',
      (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => null,
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    await tester.pumpWidget(MaterialApp(
      home: MetraRegistrationScreen(
        api: api,
        createIdentity: (_, __) async => false,
      ),
    ));
    await tester.enterText(find.byType(TextFormField).at(0), 'new@example.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'StrongPassword123');
    await tester.tap(find.text('إنشاء حساب الدخول'));
    await tester.pumpAndSettle();

    expect(find.textContaining('أكّد بريدك الإلكتروني'), findsOneWidget);
    expect(find.textContaining('صلاحيات تشغيلية'), findsOneWidget);
    api.close();
  });
}
