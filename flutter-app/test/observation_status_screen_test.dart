import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/reports/observation_status_screen.dart';

void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  testWidgets('station status loads up to 100 authorized review and returned rows', (tester) async {
    final List<http.Request> requests = <http.Request>[];
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'status-token',
      client: MockClient((request) async {
        requests.add(request);
        final returned = request.url.path.endsWith('/observations/returned');
        final row = <String, dynamic>{
          'id': returned
              ? '22222222-2222-4222-8222-222222222222'
              : '33333333-3333-4333-8333-333333333333',
          'station_id': stationId,
          'observation_type': returned ? 'phenomenon' : 'hourly',
          'observed_at': '2026-11-11T06:00:00Z',
          'payload': <String, dynamic>{
            'values': <String, dynamic>{'temperature_c': 18},
          },
          'status': returned ? 'returned' : 'submitted',
          if (returned) 'review_note': 'مراجعة مطلوبة',
        };
        return http.Response(
          jsonEncode(<dynamic>[row]),
          200,
          headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    useTallViewport(tester);
    await tester.pumpWidget(MaterialApp(
      home: ObservationStatusScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    expect(requests.every((request) =>
        request.url.path.startsWith('/api/v1/stations/$stationId/observations')), isTrue);
    expect(requests.every((request) =>
        request.url.queryParameters['limit'] == '100'), isTrue);
    expect(requests.every((request) =>
        request.headers['authorization'] == 'Bearer status-token'), isTrue);
    expect(find.text('بانتظار المراجعة'), findsOneWidget);
    expect(find.text('مُرجَعة للتصحيح'), findsOneWidget);
    expect(find.text('نشرة ساعية'), findsOneWidget);
    expect(find.text('بلاغ ظاهرة'), findsOneWidget);
    expect(find.textContaining('2026-11-11-06'), findsNothing);
    api.close();
  });

  testWidgets('station status shows authorization failure instead of empty data', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'status-token',
      client: MockClient((request) async => http.Response('forbidden', 403)),
    );

    await tester.pumpWidget(MaterialApp(
      home: ObservationStatusScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ليست لديك صلاحية قراءة نشرات هذه المحطة.'), findsOneWidget);
    expect(find.text('لا توجد نشرات بانتظار المراجعة.'), findsNothing);
    api.close();
  });
}
