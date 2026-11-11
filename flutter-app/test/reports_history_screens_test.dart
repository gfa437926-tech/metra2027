import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/admin/manual_archive_screen.dart';
import 'package:metra_mobile/features/reports/observation_history_screen.dart';
import 'package:metra_mobile/features/reports/station_reports_hub_screen.dart';

void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  testWidgets('reports hub opens station-scoped audit history', (tester) async {
    late http.Request captured;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'reports-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(<dynamic>[]), 200);
      }),
    );

    useTallViewport(tester);
    await tester.pumpWidget(MaterialApp(
      home: StationReportsHubScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    expect(find.text('تقارير المحطة'), findsOneWidget);
    expect(find.text('حالة نشرات المحطة'), findsOneWidget);
    expect(find.text('التقرير الشهري الإداري'), findsOneWidget);
    expect(find.text('سجل تدقيق المحطة والتعيينات'), findsOneWidget);

    final auditTile = find.text('سجل تدقيق المحطة والتعيينات');
    
    await tester.tap(auditTile);
    await tester.pumpAndSettle();

    expect(captured.url.path, '/api/v1/stations/$stationId/audit-log');
    expect(captured.url.queryParameters['limit'], '100');
    expect(captured.headers['authorization'], 'Bearer reports-token');
    expect(find.text('لا توجد أحداث تدقيق مسجلة لهذه المحطة.'), findsOneWidget);
    api.close();
  });

  testWidgets('manual archive supports UTC periods and month navigation', (tester) async {
    final List<http.Request> requests = <http.Request>[];
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'archive-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path.endsWith('/archive-confirmations/monthly-summary')) {
          return http.Response(jsonEncode(<String, dynamic>{
            'year': 2026,
            'month': 11,
            'confirmationCount': 0,
            'reportKinds': <String>[],
          }), 200);
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/archive-confirmations')) {
          return http.Response(jsonEncode(<dynamic>[]), 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/archive-confirmations')) {
          return http.Response(jsonEncode(<String, dynamic>{
            'id': '22222222-2222-4222-8222-222222222222',
            'reportKind': 'daily',
            'excelFileName': 'daily.xlsx',
          }), 201);
        }
        return http.Response('not found', 404);
      }),
    );

    useTallViewport(tester);
    await tester.pumpWidget(MaterialApp(
      home: ManualArchiveScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    expect(find.text('فترة التقرير بالتاريخ UTC'), findsOneWidget);
    expect(find.textContaining('من: '), findsOneWidget);
    expect(find.textContaining('إلى: '), findsOneWidget);

    final DateTime nowUtc = DateTime.now().toUtc();
    final DateTime previousMonth = DateTime.utc(nowUtc.year, nowUtc.month - 1, 1);
    await tester.tap(find.text('الشهر السابق'));
    await tester.pumpAndSettle();
    final summaryRequest = requests.lastWhere((request) =>
        request.method == 'GET' &&
        request.url.path.endsWith('/archive-confirmations/monthly-summary'));
    expect(summaryRequest.url.queryParameters['year'], '${previousMonth.year}');
    expect(summaryRequest.url.queryParameters['month'], '${previousMonth.month}');

    final fileNameField = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'اسم ملف Excel');
    
    await tester.enterText(fileNameField, 'daily.xlsx');
    await tester.pumpAndSettle();
    final confirmButton = find.widgetWithText(FilledButton, 'تأكيد الأرشفة اليدوية');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    final post = requests.firstWhere((request) =>
        request.method == 'POST' &&
        request.url.path.endsWith('/archive-confirmations'));
    final payload = jsonDecode(post.body) as Map<String, dynamic>;
    expect(payload['periodStartUtc'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(payload['periodEndUtc'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(payload['periodStartUtc'], payload['periodEndUtc']);
    expect(post.headers['authorization'], 'Bearer archive-token');
    expect(find.text('تم تسجيل تأكيد الأرشفة اليدوية.'), findsOneWidget);
    api.close();
  });

  testWidgets('observation history loads scoped queues and filters by type', (tester) async {
    final List<http.Request> requests = <http.Request>[];
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'history-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/observations/returned')) {
          return http.Response(jsonEncode(<dynamic>[
            <String, dynamic>{
              'id': '33333333-3333-4333-8333-333333333333',
              'station_id': stationId,
              'observation_type': 'daily',
              'observed_at': '2026-11-10T12:00:00Z',
              'payload': <String, dynamic>{'values': <String, dynamic>{'rainfall_mm': 2}},
              'status': 'returned',
              'review_note': 'يرجى مراجعة القيمة',
            },
          ]), 200, headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          });
        }
        return http.Response(jsonEncode(<dynamic>[
          <String, dynamic>{
            'id': '44444444-4444-4444-8444-444444444444',
            'station_id': stationId,
            'observation_type': 'hourly',
            'observed_at': '2026-11-11T06:00:00Z',
            'payload': <String, dynamic>{'values': <String, dynamic>{'temperature_c': 18}},
            'status': 'submitted',
          },
        ]), 200);
      }),
    );

    final directReview = await api.getReviewQueue(stationId, limit: 50);
    final directReturned = await api.getReturnedObservations(stationId, limit: 50);
    expect(directReview, hasLength(1));
    expect(directReturned, hasLength(1));

    useTallViewport(tester);
    await tester.pumpWidget(MaterialApp(
      home: ObservationHistoryScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(requests, hasLength(4));
    expect(requests.every((request) =>
        request.url.path.startsWith('/api/v1/stations/$stationId/observations')), isTrue);
    expect(requests.every((request) =>
        request.headers['authorization'] == 'Bearer history-token'), isTrue);
    final historyRequests = requests.skip(2);
    expect(historyRequests.every((request) =>
        request.url.queryParameters['limit'] == '100'), isTrue);
    expect(find.text('سجل النشرات المتاح'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('تعذر تحميل سجل النشرات من الخادم.'), findsNothing);
    expect(find.text('نشرة ساعية'), findsOneWidget);
    expect(find.text('نشرة يومية'), findsOneWidget);

    
    final hourlyChip = find.ancestor(
      of: find.text('ساعي'),
      matching: find.byType(FilterChip),
    );
    await tester.tap(hourlyChip);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(hourlyChip).selected, isTrue);
    expect(find.text('نشرة يومية'), findsNothing);

    await tester.tap(find.text('الكل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مُرجَعة'));
    await tester.pumpAndSettle();
    expect(find.text('نشرة ساعية'), findsNothing);
    expect(find.text('نشرة يومية'), findsOneWidget);

    final searchField = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'بحث في السجل');
    await tester.enterText(searchField, 'يرجى مراجعة القيمة');
    await tester.pumpAndSettle();
    expect(find.text('نشرة يومية'), findsOneWidget);

    await tester.tap(find.text('مسح كل المرشحات'));
    await tester.pumpAndSettle();
    expect(find.text('نشرة ساعية'), findsOneWidget);
    expect(find.text('نشرة يومية'), findsOneWidget);

    await tester.tap(find.text('نشرة ساعية'));
    await tester.pumpAndSettle();
    expect(find.text('حقول الحمولة (كما أعادها الخادم)'), findsOneWidget);
    api.close();
  });
}
