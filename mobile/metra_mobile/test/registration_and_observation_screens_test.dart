import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/home/registration_access_screen.dart';
import 'package:metra_mobile/features/observations/observation_entry_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  testWidgets('registration screen loads roles, approved stations and own account status', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'screen-test-token',
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer screen-test-token');
        switch (request.url.path) {
          case '/api/v1/registration-roles':
            return http.Response.bytes(utf8.encode(jsonEncode([
              {'role_code': 'observer', 'name_ar': 'راصد', 'name_en': 'Observer'}
            ])), 200, headers: {'content-type': 'application/json; charset=utf-8'});
          case '/api/v1/stations':
            return http.Response.bytes(utf8.encode(jsonEncode([{
              'id': stationId,
              'local_station_code': 'ST-001',
              'name_ar': 'محطة اختبار',
              'name_en': 'Test station',
              'station_type': 'classic',
              'operational_status': 'active',
              'approval_status': 'approved',
              'is_demo': false,
              'station_coordinates': <Map<String, dynamic>>[],
            }])), 200, headers: {'content-type': 'application/json; charset=utf-8'});
          case '/api/v1/account/registration-status':
            return http.Response(jsonEncode({
              'account_state': null,
              'state_reason': null,
              'request_id': null,
              'request_status': null,
              'submitted_at': null,
              'review_note': null,
            }), 200);
          default:
            return http.Response('not found', 404);
        }
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(MaterialApp(home: RegistrationAccessScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('حالة الحساب'), findsNWidgets(2));
    expect(find.text('طلب انتساب أو تحديث الطلب المرفوض'), findsOneWidget);
    expect(find.text('راصد'), findsOneWidget);
    expect(find.textContaining('محطة اختبار'), findsOneWidget);
    expect(find.text('إرسال طلب التسجيل'), findsOneWidget);
  });

  testWidgets('observation entry screen presents .NET observation payload form', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'screen-test-token',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(api.close);

    await tester.pumpWidget(MaterialApp(
      home: ObservationEntryScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    expect(find.text('إدخال رصد جديد'), findsOneWidget);
    expect(find.text('حمولة الرصد بصيغة JSON'), findsOneWidget);
    expect(find.text('حفظ الرصد'), findsOneWidget);
  });

  testWidgets('observation retry reuses the same idempotency key after an ambiguous failure', (tester) async {
    final keys = <String>[];
    var attempts = 0;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'screen-test-token',
      client: MockClient((request) async {
        attempts++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        keys.add(body['idempotencyKey'] as String);
        if (attempts == 1) {
          return http.Response('temporarily unavailable', 503);
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(MaterialApp(
      home: ObservationEntryScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حفظ الرصد'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('تعذر الاتصال بخدمة الرصد.'), findsNothing);
    expect(find.text('خدمة الرصد غير متاحة حالياً.'), findsOneWidget);

    await tester.tap(find.text('حفظ الرصد'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(keys, hasLength(2));
    expect(keys.first, isNotEmpty);
    expect(keys[1], keys.first);
  });

}
