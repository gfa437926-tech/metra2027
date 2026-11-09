import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/observations/daily_observation_contract.dart';
import 'package:metra_mobile/features/observations/daily_observation_submit_screen.dart';
import 'package:metra_mobile/features/observations/observation_submit_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  Future<Map<String, dynamic>> submitDailyType(
    WidgetTester tester,
    String reportType,
  ) async {
    late http.Request captured;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'daily-test-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': '22222222-2222-4222-8222-222222222222',
            'status': 'submitted',
            'replayed': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: DailyObservationSubmitScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    if (reportType != '24h') {
      await tester.tap(find.byKey(const ValueKey('daily-report-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(DailyObservationContract.reportTypes[reportType]!).last);
      await tester.pumpAndSettle();
    }
    final values = reportType == '24h'
        ? <String, String>{
            'minTemp': '-05.3', 'maxTemp': '25.7',
            'precipitation': '012.5', 'snowThickness': '015',
            'evaporation': '12.5', 'sunshineDuration': '08.5',
            'sunshinePercentage': '075', 'maxGustSpeed': '15',
            'maxGustDirection': '25', 'maxGustTime': '14.5',
            'maxHumidity': '085', 'maxHumidityTime': '06.0',
            'minHumidity': '35', 'minHumidityTime': '14.0',
          }
        : <String, String>{
            'minTemp': '-05.3', 'maxTemp': '25.7',
            'precipitation': '012.5', 'snowThickness': '015',
          };
    for (final entry in values.entries) {
      final field = find.byKey(ValueKey('daily-field-${entry.key}'));
      await tester.scrollUntilVisible(
        field, 300, scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field, entry.value);
    }
    final agreement = find.byKey(const ValueKey('daily-responsibility-agreement'));
    await tester.scrollUntilVisible(
      agreement, 300, scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(agreement);
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('daily-submit'));
    await tester.scrollUntilVisible(
      submit, 300, scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    api.close();
    return body;
  }

  test('daily contract selects report-specific required fields', () {
    expect(DailyObservationContract.requiredFields('06utc'), {
      'minTemp', 'maxTemp', 'precipitation', 'snowThickness',
    });
    expect(DailyObservationContract.requiredFields('18utc'), {
      'minTemp', 'maxTemp', 'precipitation', 'snowThickness',
    });
    expect(DailyObservationContract.requiredFields('24h'), hasLength(14));
    expect(DailyObservationContract.requiredFields('invalid'), isEmpty);
  });

  test('daily contract preserves missing markers and enforces ranges and relationships', () {
    expect(DailyObservationContract.validateField('minTemp', '#'), isNull);
    expect(DailyObservationContract.validateField('precipitationTrace', 't'), isNull);
    expect(DailyObservationContract.validateField('precipitationTrace', 'yes'), isNotNull);
    expect(DailyObservationContract.validateField('sunshinePercentage', '101'), isNotNull);
    final errors = DailyObservationContract.validate(
      '24h',
      {
        'minTemp': '20.0',
        'maxTemp': '10.0',
        'precipitation': '012.5',
        'snowThickness': '015',
        'evaporation': '12.5',
        'sunshineDuration': '08.5',
        'sunshinePercentage': '075',
        'maxGustSpeed': '15',
        'maxGustDirection': '25',
        'maxGustTime': '14.5',
        'maxHumidity': '085',
        'maxHumidityTime': '06.0',
        'minHumidity': '90',
        'minHumidityTime': '14.0',
      },
      responsibilityAgreement: false,
    );
    expect(errors.keys, containsAll(['maxTemp', 'minHumidity', 'responsibilityAgreement']));
  });

  testWidgets('06 UTC daily report submits the exact canonical envelope', (tester) async {
    late http.Request captured;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'daily-test-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': '22222222-2222-4222-8222-222222222222',
            'status': 'submitted',
            'replayed': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: DailyObservationSubmitScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('daily-report-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نشرة الرصد عند 06 UTC').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('daily-field-minTemp')), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-field-evaporation')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('daily-field-minTemp')), '-05.3');
    await tester.enterText(find.byKey(const ValueKey('daily-field-maxTemp')), '25.7');
    await tester.enterText(find.byKey(const ValueKey('daily-field-precipitation')), '012.5');
    await tester.enterText(find.byKey(const ValueKey('daily-field-snowThickness')), '015');

    final agreement = find.byKey(const ValueKey('daily-responsibility-agreement'));
    await tester.scrollUntilVisible(agreement, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(agreement);
    await tester.pumpAndSettle();

    final submit = find.byKey(const ValueKey('daily-submit'));
    await tester.scrollUntilVisible(submit, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/stations/$stationId/observations');
    expect(captured.headers['authorization'], 'Bearer daily-test-token');
    expect(body['observationType'], 'daily');
    expect(body['submit'], isTrue);
    expect(body['payload']['reportType'], '06utc');
    expect(body['payload']['responsibilityAgreement'], isTrue);
    expect(body['payload']['values'], {
      'minTemp': '-05.3',
      'maxTemp': '25.7',
      'precipitation': '012.5',
      'snowThickness': '015',
    });
    expect(body['observedAt'], endsWith('T06:00:00.000Z'));
    expect(find.textContaining('تم حفظ النشرة اليومية وإرسالها للمراجعة'), findsOneWidget);
    api.close();
  });

  testWidgets('24-hour daily report submits all canonical required fields',
      (tester) async {
    final body = await submitDailyType(tester, '24h');
    expect(body['observationType'], 'daily');
    expect(body['payload']['reportType'], '24h');
    expect(body['payload']['responsibilityAgreement'], isTrue);
    expect((body['payload']['values'] as Map).keys, containsAll([
      'minTemp', 'maxTemp', 'precipitation', 'snowThickness',
      'evaporation', 'sunshineDuration', 'sunshinePercentage',
      'maxGustSpeed', 'maxGustDirection', 'maxGustTime',
      'maxHumidity', 'maxHumidityTime', 'minHumidity', 'minHumidityTime',
    ]));
    expect(body['payload']['values']['sunshinePercentage'], '075');
    expect(body['observedAt'], endsWith('T00:00:00.000Z'));
  });

  testWidgets('18 UTC daily report submits only its canonical required fields',
      (tester) async {
    final body = await submitDailyType(tester, '18utc');
    expect(body['observationType'], 'daily');
    expect(body['payload']['reportType'], '18utc');
    expect(body['payload']['responsibilityAgreement'], isTrue);
    expect(body['payload']['values'], {
      'minTemp': '-05.3',
      'maxTemp': '25.7',
      'precipitation': '012.5',
      'snowThickness': '015',
    });
    expect(body['observedAt'], endsWith('T18:00:00.000Z'));
  });

  testWidgets('hourly entry exposes navigation to the daily form', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'navigation-token',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await tester.pumpWidget(MaterialApp(
      home: ObservationSubmitScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    final openDaily = find.byKey(const ValueKey('open-daily-observation'));
    await tester.ensureVisible(openDaily);
    await tester.tap(openDaily);
    await tester.pumpAndSettle();
    expect(find.text('إدخال نشرة يومية'), findsOneWidget);
    expect(find.text('نوع النشرة'), findsOneWidget);
    api.close();
  });

  testWidgets('daily form refuses submission until responsibility is acknowledged',
      (tester) async {
    var requests = 0;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'daily-test-token',
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: DailyObservationSubmitScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('daily-submit'));
    await tester.scrollUntilVisible(submit, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.text('يجب تأكيد إقرار المسؤولية'), findsOneWidget);
    api.close();
  });
}
