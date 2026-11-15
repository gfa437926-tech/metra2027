import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/forecast_centres/forecast_centre_screen.dart';

void main() {
  testWidgets('forecast centre exposes greenfield readiness gate without legacy HTTP', (tester) async {
    var requests = 0;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'forecast-token',
      client: MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ForecastCentreScreen(api: api))),
    );
    await tester.pumpAndSettle();
    expect(find.text('مراكز التنبؤ الجوي'), findsOneWidget);
    expect(find.text('دليل المحطات غير مفعّل بعد'), findsOneWidget);
    expect(find.textContaining('المصدر القديم'), findsOneWidget);
    expect(requests, 0);
    api.close();
  });

  testWidgets('forecast centre retry remains fail-closed while greenfield API is gated', (tester) async {
    var requests = 0;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'forecast-token',
      client: MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ForecastCentreScreen(api: api))),
    );
    await tester.pumpAndSettle();
    expect(find.text('دليل المحطات غير مفعّل بعد'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('دليل المحطات غير مفعّل بعد'), findsOneWidget);
    expect(requests, 0);
    api.close();
  });

  testWidgets('forecast centre does not pretend to check permissions while the API is gated', (tester) async {
    var requests = 0;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'forecast-token',
      client: MockClient((_) async {
        requests++;
        return http.Response(
          '{"error":"forbidden"}',
          403,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ForecastCentreScreen(api: api))),
    );
    await tester.pumpAndSettle();
    expect(find.text('دليل المحطات غير مفعّل بعد'), findsOneWidget);
    expect(find.text('تعذر تحميل دليل المحطات'), findsNothing);
    expect(requests, 0);
    api.close();
  });
}
