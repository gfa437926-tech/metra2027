import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/observations/observation_submit_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  testWidgets('hourly form converts station local hour and submits canonical values',
      (tester) async {
    late http.Request captured;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'hourly-test-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': '33333333-3333-4333-8333-333333333333',
            'status': 'submitted',
            'replayed': false,
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: ObservationSubmitScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    final hour = find.byKey(const ValueKey('hourly-local-hour'));
    await tester.tap(hour);
    await tester.pumpAndSettle();
    await tester.tap(find.text('04').last);
    await tester.pumpAndSettle();
    expect(find.text('سيُرسل التوقيت العالمي UTC: 01:00'), findsOneWidget);

    const entries = <String, String>{
      'الحرارة الجافة (مثل +25.0) *': '+25.0',
      'الحرارة الرطبة (مثل +20.0) *': '+20.0',
      'نقطة الندى (مثل +18.5) *': '+18.5',
      'ضغط المحطة (مثل 1013.2) *': '1013.2',
      'الضغط عند سطح البحر (مثل 1013.2) *': '1013.2',
      'الرطوبة النسبية (ثلاث خانات مثل 065) *': '065',
      'اتجاه الرياح (00-36) *': '18',
      'سرعة الرياح (خانتان) *': '12',
      'مدى الرؤية (000-200) *': '050',
      'التغطية الكلية للسحب (0-8) *': '4',
      'تغطية الطبقتين الأولى والثانية (0-8) *': '4',
      'تغطية الطبقات الثلاث (0-8) *': '5',
    };
    for (final entry in entries.entries) {
      final field = find.byKey(ValueKey('hourly-field-${entry.key}'));
      await tester.scrollUntilVisible(field, 300, scrollable: find.byType(Scrollable).first);
      await tester.enterText(field, entry.value);
    }

    final submit = find.byKey(const ValueKey('hourly-submit'));
    await tester.scrollUntilVisible(submit, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['observationType'], 'hourly');
    expect(body['submit'], isTrue);
    expect(body['payload']['values']['utcTime'], '01');
    expect(body['payload']['values']['dryTemp'], '+25.0');
    expect(body['payload']['values']['totalCloudCover'], '4');
    expect(body['payload']['values']['cloudCover'], isNull);
    expect(body['payload']['values']['precipitationAmount'], isNull);
    expect(body['observedAt'], endsWith('T01:00:00.000Z'));
    expect(find.textContaining('تم حفظ النشرة وإرسالها للمراجعة'), findsOneWidget);
    api.close();
  });

  testWidgets('hourly form blocks impossible wet and dry temperature relationship',
      (tester) async {
    var requests = 0;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'hourly-test-token',
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: ObservationSubmitScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    const values = <String, String>{
      'الحرارة الجافة (مثل +25.0) *': '+20.0',
      'الحرارة الرطبة (مثل +20.0) *': '+25.0',
    };
    for (final entry in values.entries) {
      final field = find.byKey(ValueKey('hourly-field-${entry.key}'));
      await tester.scrollUntilVisible(field, 300, scrollable: find.byType(Scrollable).first);
      await tester.enterText(field, entry.value);
    }
    final submit = find.byKey(const ValueKey('hourly-submit'));
    await tester.scrollUntilVisible(submit, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(requests, 0);
    expect(find.text('الحرارة الرطبة يجب ألا تتجاوز الحرارة الجافة'), findsOneWidget);
    api.close();
  });
}
