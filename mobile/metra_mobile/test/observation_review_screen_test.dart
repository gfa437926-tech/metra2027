import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/observations/observation_review_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  testWidgets('renders queue returned by the API', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'access-token',
      client: MockClient((_) async => http.Response(jsonEncode([
        {
          'id': '22222222-2222-4222-8222-222222222222',
          'station_id': stationId,
          'observation_type': 'daily',
          'observed_at': '2026-11-03T12:00:00Z',
          'status': 'submitted',
          'payload': {}
        }
      ]), 200)),
    );

    await tester.pumpWidget(MaterialApp(
      home: ObservationReviewScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    expect(find.text('مراجعة النشرات'), findsOneWidget);
    expect(find.text('نشرة يومية'), findsOneWidget);
    api.close();
  });

  testWidgets('shows an empty state for an empty server queue', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'access-token',
      client: MockClient((_) async => http.Response('[]', 200)),
    );

    await tester.pumpWidget(MaterialApp(
      home: ObservationReviewScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نشرات بانتظار المراجعة'), findsOneWidget);
    api.close();
  });

  testWidgets('localizes queue status and expands payload details', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'access-token',
      client: MockClient((_) async => http.Response(jsonEncode([
        {
          'id': '33333333-3333-4333-8333-333333333333',
          'station_id': stationId,
          'observation_type': 'hourly',
          'observed_at': '2026-11-10T12:00:00Z',
          'status': 'submitted',
          'payload': {'dryTemp': '+21.0', 'relativeHumidity': 65}
        }
      ]), 200)),
    );

    await tester.pumpWidget(MaterialApp(
      home: ObservationReviewScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('بانتظار المراجعة'), findsOneWidget);
    await tester.tap(find.text('تفاصيل بيانات النشرة'));
    await tester.pumpAndSettle();
    expect(find.text('درجة الحرارة الجافة'), findsOneWidget);
    expect(find.text('+21.0'), findsOneWidget);
    expect(find.text('الرطوبة النسبية'), findsOneWidget);
    api.close();
  });

}
