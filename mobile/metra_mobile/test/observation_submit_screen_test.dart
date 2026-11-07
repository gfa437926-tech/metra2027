import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/observations/observation_submit_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  testWidgets('rejects out-of-range temperature before calling API', (tester) async {
    var called = false;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        called = true;
        return http.Response(
          jsonEncode({'id': stationId}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: ObservationSubmitScreen(api: api, stationId: stationId),
    ));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '999');
    await tester.enterText(fields.at(1), '20');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ النشرة'));
    await tester.pump();

    expect(find.textContaining('خارج المدى'), findsWidgets);
    expect(called, isFalse);
    api.close();
  });
}
