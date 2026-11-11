import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/reports/observation_archive_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';
  const observationId = '66666666-6666-4666-8666-666666666666';

  testWidgets('archive screen loads station records and opens source payload detail', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'archive-token',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/archive')) {
          return http.Response(jsonEncode({
            'authorized': true,
            'items': [{
              'id': observationId,
              'stationId': stationId,
              'sourceSystem': 'legacy-import',
              'sourceTable': 'hourly_records',
              'sourceRecordId': 'source-1',
              'observationType': 'hourly',
              'observedAtUtc': '2026-11-10T18:00:00Z',
              'payload': {'temperature': 24},
              'importedAtUtc': '2026-11-11T01:00:00Z'
            }],
            'page': {'limit': 50, 'offset': 0, 'returned': 1}
          }), 200);
        }
        return http.Response(jsonEncode({
          'authorized': true,
          'found': true,
          'item': {
            'id': observationId,
            'stationId': stationId,
            'sourceSystem': 'legacy-import',
            'sourceTable': 'hourly_records',
            'sourceRecordId': 'source-1',
            'observationType': 'hourly',
            'observedAtUtc': '2026-11-10T18:00:00Z',
            'payload': {'temperature': 24},
            'importedAtUtc': '2026-11-11T01:00:00Z'
          }
        }), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationArchiveScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('الأرشيف التاريخي للرصدات'), findsOneWidget);
    expect(find.text('رصد ساعي'), findsOneWidget);

    await tester.tap(find.text('رصد ساعي'));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل الرصد التاريخي'), findsOneWidget);
    expect(find.text('محتوى الرصد الأصلي'), findsOneWidget);
    expect(find.textContaining('temperature'), findsOneWidget);
    api.close();
  });

  testWidgets('archive screen asks user to select a station before loading', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationArchiveScreen(api: api, stationId: null)),
    ));
    expect(find.text('اختر محطة أولاً'), findsOneWidget);
    expect(find.textContaining('افتح دليل المحطات'), findsOneWidget);
    api.close();
  });
}
