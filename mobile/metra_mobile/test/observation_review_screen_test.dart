import 'dart:convert';

import 'package:material_ui/material_ui.dart';
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

  testWidgets('shows a permission message when a review decision is forbidden', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'access-token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode([
            {
              'id': '22222222-2222-4222-8222-222222222222',
              'station_id': stationId,
              'observation_type': 'daily',
              'observed_at': '2026-11-03T12:00:00Z',
              'status': 'submitted',
              'payload': {}
            }
          ]), 200);
        }
        return http.Response('{"error":"forbidden"}', 403);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: ObservationReviewScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اعتماد'));
    await tester.pumpAndSettle();

    expect(find.text('ليست لديك صلاحية تنفيذ هذا القرار'), findsOneWidget);
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
}
