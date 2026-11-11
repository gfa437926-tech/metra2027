import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/observations/phenomenon_capture_screen.dart';

void main() {
  testWidgets('phenomenon is validated then submitted with a server receipt',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? validationBody;
    Map<String, dynamic>? submissionBody;
    var submissions = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/observations/phenomena/validate') {
        validationBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'isValid': true, 'issues': []})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.method == 'POST' &&
          request.url.path ==
              '/api/v1/stations/11111111-1111-4111-8111-111111111111/observations') {
        submissions++;
        submissionBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'id': 'observation-phenomenon-1'})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not_found', 404);
    });
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'phenomenon-token',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(
      home: PhenomenonCaptureScreen(
        api: api,
        stationId: '11111111-1111-4111-8111-111111111111',
      ),
    ));
    await tester.enterText(find.byType(TextField).at(0), 'مطر خفيف');
    await tester.enterText(find.byType(TextField).at(1), 'هطول مستمر');
    await tester.pump();

    await tester.tap(find.text('بدء الظاهرة'));
    await tester.pump();
    await tester.tap(find.text('إنهاء والتحقق والحفظ'));
    await tester.pumpAndSettle();

    expect(validationBody?['phenomenonType'], 'مطر خفيف');
    expect(validationBody?['phenomenonDate'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(validationBody?['startTime'], matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));
    expect(validationBody?['endTime'], matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));
    expect(submissions, 1);
    expect(submissionBody?['observationType'], 'phenomenon');
    expect(submissionBody?['submit'], isTrue);
    expect(submissionBody?['idempotencyKey'], startsWith('phenomenon-'));
    final payload = submissionBody?['payload'] as Map<String, dynamic>;
    final values = payload['values'] as Map<String, dynamic>;
    expect(values['phenomenonType'], 'مطر خفيف');
    expect(values['status'], 'منتهية');
    expect(values['notes'], 'هطول مستمر');
    expect(find.text('observation-phenomenon-1'), findsOneWidget);
    expect(find.text('تم حفظ الظاهرة'), findsOneWidget);
    api.close();
  });

  testWidgets('invalid phenomenon is not submitted to observation storage',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var submissionAttempts = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/observations/phenomena/validate') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'isValid': false,
            'issues': [
              {'field': 'phenomenon_type', 'message': 'نوع الظاهرة مطلوب'},
            ],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      submissionAttempts++;
      return http.Response('unexpected_submission', 500);
    });
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'phenomenon-token',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(
      home: PhenomenonCaptureScreen(
        api: api,
        stationId: '11111111-1111-4111-8111-111111111111',
      ),
    ));
    await tester.enterText(find.byType(TextField).at(0), 'ضباب');
    await tester.tap(find.text('بدء الظاهرة'));
    await tester.pump();
    await tester.tap(find.text('إنهاء والتحقق والحفظ'));
    await tester.pumpAndSettle();

    expect(submissionAttempts, 0);
    expect(find.textContaining('نوع الظاهرة مطلوب'), findsOneWidget);
    expect(find.text('تم حفظ الظاهرة'), findsNothing);
    api.close();
  });
}
