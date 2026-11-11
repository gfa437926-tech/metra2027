import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/admin/manual_archive_screen.dart';
import 'package:metra_mobile/features/reports/station_reports_hub_screen.dart';

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

    await tester.enterText(find.widgetWithText(TextField, 'اسم ملف Excel'), 'daily.xlsx');
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
}
