import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/admin/manual_archive_screen.dart';
import 'package:metra_mobile/features/reports/station_reports_hub_screen.dart';
import 'package:metra_mobile/features/reports/observation_history_screen.dart';

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

    await tester.pumpWidget(MaterialApp(
      home: StationReportsHubScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    expect(find.text('تقارير المحطة'), findsOneWidget);
    expect(find.text('حالة نشرات المحطة'), findsOneWidget);
    expect(find.text('التقرير الشهري الإداري'), findsOneWidget);
    expect(find.text('سجل تدقيق المحطة والتعيينات'), findsOneWidget);

    await tester.tap(find.text('سجل تدقيق المحطة والتعيينات'));
    await tester.pumpAndSettle();

    expect(captured.url.path, '/api/v1/stations/$stationId/audit-log');
    expect(captured.url.queryParameters['limit'], '100');
    expect(captured.headers['authorization'], 'Bearer reports-token');
    expect(find.text('لا توجد أحداث تدقيق مسجلة لهذه المحطة.'), findsOneWidget);
    api.close();
  });

  testWidgets('manual archive uses a selectable UTC report period', (tester) async {
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

    await tester.enterText(
      find.byWidgetPredicate((widget) =>
          widget is TextField && widget.decoration?.labelText == 'اسم ملف Excel'),
      'daily.xlsx',
    );
    await tester.tap(find.text('تأكيد الأرشفة اليدوية'));
    await tester.pumpAndSettle();

    final post = requests.firstWhere((request) =>
        request.method == 'POST' &&
        request.url.path.endsWith('/archive-confirmations'));
    final payload = jsonDecode(post.body) as Map<String, dynamic>;
    expect(payload['periodStartUtc'], matches(RegExp(r'^\\d{4}-\\d{2}-\\d{2}$')));
    expect(payload['periodEndUtc'], matches(RegExp(r'^\\d{4}-\\d{2}-\\d{2}$')));
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
          ]), 200);
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

    await tester.pumpWidget(MaterialApp(
      home: ObservationHistoryScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    expect(requests.every((request) =>
        request.url.path.startsWith('/api/v1/stations/$stationId/observations')), isTrue);
    expect(requests.every((request) =>
        request.headers['authorization'] == 'Bearer history-token'), isTrue);
    expect(find.text('سجل النشرات المتاح'), findsOneWidget);
    expect(find.text('نشرة ساعية'), findsOneWidget);
    expect(find.text('نشرة يومية'), findsOneWidget);
    expect(find.text('السجلات المطابقة: 2 من 2 سجلاً محمّلاً'), findsOneWidget);

    await tester.tap(find.text('ساعي'));
    await tester.pumpAndSettle();

    expect(find.text('نشرة ساعية'), findsOneWidget);
    expect(find.text('نشرة يومية'), findsNothing);
    expect(find.text('السجلات المطابقة: 1 من 2 سجلاً محمّلاً'), findsOneWidget);
    api.close();
  });

}
