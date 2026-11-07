import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/observations/observation_review_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  MetraApiClient buildApi({
    required List<Map<String, dynamic>> review,
    required List<Map<String, dynamic>> returned,
  }) {
    return MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'access-token',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/observations/returned')) {
          return http.Response(jsonEncode(returned), 200);
        }
        if (path.contains('/observations')) {
          return http.Response(jsonEncode(review), 200);
        }
        return http.Response('not found', 404);
      }),
    );
  }

  testWidgets('renders queue returned by the API', (tester) async {
    final api = buildApi(
      review: [
        {
          'id': '22222222-2222-4222-8222-222222222222',
          'station_id': stationId,
          'observation_type': 'daily',
          'observed_at': '2026-11-03T12:00:00Z',
          'status': 'submitted',
          'payload': {}
        }
      ],
      returned: const [],
    );

    await tester.pumpWidget(MaterialApp(
      home: ObservationReviewScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    expect(find.text('مراجعة النشرات'), findsOneWidget);
    expect(find.text('نشرة يومية'), findsOneWidget);
    expect(find.text('طابور المراجعة'), findsOneWidget);
    expect(find.text('مُرجَعة لإعادة التقديم'), findsOneWidget);
    api.close();
  });

  testWidgets('shows an empty state for an empty server queue', (tester) async {
    final api = buildApi(review: const [], returned: const []);

    await tester.pumpWidget(MaterialApp(
      home: ObservationReviewScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نشرات بانتظار المراجعة'), findsOneWidget);
    api.close();
  });

  testWidgets('shows returned observations for resubmit', (tester) async {
    final api = buildApi(
      review: const [],
      returned: [
        {
          'id': '33333333-3333-4333-8333-333333333333',
          'station_id': stationId,
          'observation_type': 'hourly',
          'observed_at': '2026-11-03T13:00:00Z',
          'status': 'returned',
          'review_note': 'راجع درجة الحرارة',
          'payload': {'dry_temp': '20.0'}
        }
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: ObservationReviewScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مُرجَعة لإعادة التقديم'));
    await tester.pumpAndSettle();
    expect(find.text('نشرة ساعية'), findsOneWidget);
    expect(find.text('إعادة التقديم'), findsOneWidget);
    api.close();
  });
}
