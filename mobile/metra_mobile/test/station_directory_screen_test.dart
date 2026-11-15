import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/stations/station_directory_screen.dart';

void main() {
  testWidgets('greenfield station directory remains visibly fail-closed',
      (tester) async {
    var requests = 0;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'test-token',
      client: MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: StationDirectoryScreen(api: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحميل دليل المحطات'), findsOneWidget);
    expect(
      find.textContaining('حتى اكتمال ربط قاعدة البيانات الجديدة'),
      findsOneWidget,
    );
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(requests, 0);

    await tester.tap(find.text('القائمة'));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل دليل المحطات'), findsOneWidget);
    expect(requests, 0);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل دليل المحطات'), findsOneWidget);
    expect(requests, 0);

    api.close();
  });
}
