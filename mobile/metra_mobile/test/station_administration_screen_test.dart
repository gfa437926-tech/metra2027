import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/admin/station_administration_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';
  const requestId = '33333333-3333-4333-8333-333333333333';

  Map<String, dynamic> registrationRequest() => {
        'id': requestId,
        'full_name': 'مراقب تجريبي',
        'requested_role_code': 'observer',
        'status': 'pending',
        'email': 'observer@example.test',
      };

  MetraApiClient apiWith(MockClientHandler handler) => MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'access-token',
        client: MockClient(handler),
      );

  /// http.Response(String) encodes latin1; Arabic JSON must use utf8 body bytes.
  http.Response jsonOk(Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );

  http.Response emptyList() => http.Response('[]', 200);

  testWidgets('renders four admin tabs in RTL shell', (tester) async {
    final api = apiWith((_) async => emptyList());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationAdministrationScreen(api: api, stationId: stationId),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('مستخدمو المحطة'), findsOneWidget);
    expect(find.text('طلبات التسجيل'), findsOneWidget);
    expect(find.text('أرصاد للمراجعة'), findsOneWidget);
    expect(find.text('سجل التدقيق'), findsOneWidget);
    api.close();
  });

  testWidgets('registration queue shows approve and reject actions',
      (tester) async {
    final api = apiWith((request) async {
      if (request.url.path.contains('registration-requests')) {
        return jsonOk([registrationRequest()]);
      }
      return emptyList();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationAdministrationScreen(api: api, stationId: stationId),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلبات التسجيل'));
    await tester.pumpAndSettle();
    expect(find.text('مراقب تجريبي'), findsOneWidget);
    expect(find.text('اعتماد'), findsOneWidget);
    expect(find.text('رفض'), findsOneWidget);
    api.close();
  });

  testWidgets('registration list 403 shows operator permission message',
      (tester) async {
    final api = apiWith((request) async {
      if (request.url.path.contains('registration-requests')) {
        return http.Response('forbidden', 403);
      }
      return emptyList();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationAdministrationScreen(api: api, stationId: stationId),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلبات التسجيل'));
    await tester.pumpAndSettle();
    expect(find.textContaining('صلاحية'), findsOneWidget);
    api.close();
  });

  testWidgets('observations tab maps queue load 403 via presenter',
      (tester) async {
    final api = apiWith((request) async {
      if (request.url.path.contains('/observations')) {
        return http.Response('forbidden', 403);
      }
      return emptyList();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationAdministrationScreen(api: api, stationId: stationId),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أرصاد للمراجعة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('صلاحية'), findsOneWidget);
    api.close();
  });

  testWidgets('approve registration posts decision and shows success snackbar',
      (tester) async {
    var decisionBodies = <String>[];
    final api = apiWith((request) async {
      if (request.method == 'POST' &&
          request.url.path.contains('/decision')) {
        decisionBodies.add(request.body);
        return http.Response('{}', 200);
      }
      if (request.url.path.contains('registration-requests')) {
        return jsonOk([registrationRequest()]);
      }
      return emptyList();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationAdministrationScreen(api: api, stationId: stationId),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلبات التسجيل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعتماد'));
    await tester.pumpAndSettle();
    expect(find.text('اعتماد طلب التسجيل'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
    await tester.pumpAndSettle();
    expect(decisionBodies, hasLength(1));
    expect(decisionBodies.single, contains('approve'));
    expect(find.textContaining('تم إرسال قرار المراجعة'), findsOneWidget);
    api.close();
  });

  testWidgets('reject registration requires reason before posting',
      (tester) async {
    var decisionBodies = <String>[];
    final api = apiWith((request) async {
      if (request.method == 'POST' &&
          request.url.path.contains('/decision')) {
        decisionBodies.add(request.body);
        return http.Response('{}', 200);
      }
      if (request.url.path.contains('registration-requests')) {
        return jsonOk([registrationRequest()]);
      }
      return emptyList();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationAdministrationScreen(api: api, stationId: stationId),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلبات التسجيل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رفض'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
    await tester.pumpAndSettle();
    expect(decisionBodies, isEmpty);
    expect(find.textContaining('سبب الرفض'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'بيانات غير مكتملة');
    await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
    await tester.pumpAndSettle();
    expect(decisionBodies, hasLength(1));
    expect(decisionBodies.single, contains('reject'));
    expect(decisionBodies.single, contains('بيانات غير مكتملة'));
    api.close();
  });

  testWidgets('registration decision 403 uses registrationDecisionMessage',
      (tester) async {
    final api = apiWith((request) async {
      if (request.method == 'POST') {
        return http.Response('forbidden', 403);
      }
      if (request.url.path.contains('registration-requests')) {
        return jsonOk([registrationRequest()]);
      }
      return emptyList();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationAdministrationScreen(api: api, stationId: stationId),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلبات التسجيل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعتماد'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
    await tester.pumpAndSettle();
    expect(find.textContaining('صلاحية'), findsOneWidget);
    expect(find.text('مراقب تجريبي'), findsOneWidget);
    api.close();
  });

  testWidgets('station switch while registration dialog is open drops stale action',
      (tester) async {
    const otherStationId = '44444444-4444-4444-8444-444444444444';
    var decisionCalls = 0;
    final getPaths = <String>[];
    final api = apiWith((request) async {
      if (request.method == 'POST' &&
          request.url.path.contains('/decision')) {
        decisionCalls++;
        return http.Response('{}', 200);
      }
      if (request.method == 'GET') {
        getPaths.add(request.url.path);
      }
      if (request.url.path.contains('registration-requests')) {
        return jsonOk([registrationRequest()]);
      }
      return emptyList();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationAdministrationScreen(api: api, stationId: stationId),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلبات التسجيل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعتماد'));
    await tester.pumpAndSettle();
    expect(find.text('اعتماد طلب التسجيل'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationAdministrationScreen(api: api, stationId: otherStationId),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
    await tester.pumpAndSettle();

    expect(decisionCalls, 0);
    expect(getPaths.any((path) => path.contains(otherStationId)), isTrue);
    api.close();
  });

  testWidgets('concurrent registration approve only posts once', (tester) async {
    final gate = Completer<void>();
    var decideCalls = 0;
    final api = apiWith((request) async {
      if (request.method == 'POST' &&
          request.url.path.contains('/decision')) {
        decideCalls++;
        await gate.future;
        return http.Response('{}', 200);
      }
      if (request.url.path.contains('registration-requests')) {
        return jsonOk([registrationRequest()]);
      }
      return emptyList();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationAdministrationScreen(api: api, stationId: stationId),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلبات التسجيل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعتماد'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
    await tester.pump();

    expect(find.text('جارٍ...'), findsOneWidget);
    await tester.tap(find.text('رفض'), warnIfMissed: false);
    await tester.pump();
    expect(decideCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(decideCalls, 1);
    api.close();
  });
}
