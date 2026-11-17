import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/core/drafts/observation_draft_store.dart';
import 'package:metra_mobile/features/observations/daily_observation_screen.dart';
import 'package:metra_mobile/features/observations/hourly_observation_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  setUp(() {
    ObservationDraftStore.instance.clearAll();
  });

  MetraApiClient apiWith(MockClientHandler handler) => MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'token',
        client: MockClient(handler),
      );

  testWidgets('hourly screen shows title and configured submit label',
      (tester) async {
    final api = apiWith((_) async => http.Response('{}', 200));
    await tester.pumpWidget(MaterialApp(
      home: HourlyObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    expect(find.text('الرصد الساعي'), findsOneWidget);
    expect(find.text('التحقق وإرسال الرصد الساعي'), findsOneWidget);
    expect(find.byType(FilledButton), findsWidgets);
    api.close();
  });

  testWidgets('daily screen shows title and configured submit label',
      (tester) async {
    final api = apiWith((_) async => http.Response('{}', 200));
    await tester.pumpWidget(MaterialApp(
      home: DailyObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    expect(find.text('الرصد اليومي'), findsOneWidget);
    expect(find.text('التحقق وإرسال الرصد اليومي'), findsOneWidget);
    api.close();
  });

  testWidgets('hourly empty submit is blocked before network', (tester) async {
    var networkCalls = 0;
    final api = apiWith((_) async {
      networkCalls++;
      return http.Response('{}', 200);
    });
    await tester.pumpWidget(MaterialApp(
      home: HourlyObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    final submit = find.text('التحقق وإرسال الرصد الساعي');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(networkCalls, 0);
    api.close();
  });

  testWidgets('daily empty submit is blocked before network', (tester) async {
    var networkCalls = 0;
    final api = apiWith((_) async {
      networkCalls++;
      return http.Response('{}', 200);
    });
    await tester.pumpWidget(MaterialApp(
      home: DailyObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    final submit = find.text('التحقق وإرسال الرصد اليومي');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(networkCalls, 0);
    api.close();
  });

  testWidgets('hourly restores local draft banner without claiming server save',
      (tester) async {
    ObservationDraftStore.instance.save(
      stationId: stationId,
      formType: 'hourly',
      values: const {'dryTemp': 21.5, 'utcTime': '09'},
    );
    final api = apiWith((_) async => http.Response('{}', 200));
    await tester.pumpWidget(MaterialApp(
      home: HourlyObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('مسودة محلية فقط'), findsOneWidget);
    expect(find.text('تجاهل المسودة المحلية'), findsOneWidget);
    api.close();
  });

  testWidgets('discarding hourly draft clears banner and store', (tester) async {
    ObservationDraftStore.instance.save(
      stationId: stationId,
      formType: 'hourly',
      values: const {'dryTemp': 21.5},
    );
    final api = apiWith((_) async => http.Response('{}', 200));
    await tester.pumpWidget(MaterialApp(
      home: HourlyObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تجاهل المسودة المحلية'));
    await tester.pumpAndSettle();
    expect(find.textContaining('مسودة محلية فقط'), findsNothing);
    expect(ObservationDraftStore.instance.get(stationId, 'hourly'), isNull);
    api.close();
  });

  test('client converts local observedAt offset to UTC ISO for hourly submit',
      () async {
    late http.Request captured;
    final api = apiWith((request) async {
      captured = request;
      return http.Response('{}', 201);
    });
    await api.submitObservation(
      stationId: stationId,
      idempotencyKey: 'hourly-utc-key',
      observationType: 'hourly',
      observedAt: DateTime.parse('2026-11-16T15:30:00+03:00'),
      payload: const {'utcTime': '12'},
      submit: true,
    );
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['observedAt'], '2026-11-16T12:30:00.000Z');
    expect(body['observationType'], 'hourly');
    api.close();
  });

  test('client converts local observedAt offset to UTC ISO for daily submit',
      () async {
    late http.Request captured;
    final api = apiWith((request) async {
      captured = request;
      return http.Response('{}', 201);
    });
    await api.submitObservation(
      stationId: stationId,
      idempotencyKey: 'daily-utc-key',
      observationType: 'daily',
      observedAt: DateTime.parse('2026-11-16T03:00:00+03:00'),
      payload: const {'currentDate': '2026-11-16'},
      submit: true,
    );
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['observedAt'], '2026-11-16T00:00:00.000Z');
    expect(body['observationType'], 'daily');
    api.close();
  });

  test(
      '403 on hourly submit yields Arabic displayMessage without status code leak pattern',
      () async {
    final api = apiWith((_) async => http.Response('forbidden', 403));
    try {
      await api.submitObservation(
        stationId: stationId,
        idempotencyKey: 'k403',
        observationType: 'hourly',
        observedAt: DateTime.utc(2026, 11, 16),
        payload: const {'utcTime': '00'},
        submit: true,
      );
      fail('expected MetraApiException');
    } on MetraApiException catch (error) {
      expect(error.statusCode, 403);
      expect(error.displayMessage, isNot(contains('403')));
      expect(error.displayMessage, isNot(contains('forbidden')));
      expect(
        error.displayMessage,
        anyOf(contains('صلاحية'), contains('جلسة'), contains('الدخول')),
      );
    }
    api.close();
  });

  test('409 conflict maps to Arabic operator message for daily', () async {
    final api = apiWith((_) async => http.Response('{}', 409));
    try {
      await api.submitObservation(
        stationId: stationId,
        idempotencyKey: 'k409',
        observationType: 'daily',
        observedAt: DateTime.utc(2026, 11, 16),
        payload: const {'currentDate': '2026-11-16'},
        submit: true,
      );
      fail('expected MetraApiException');
    } on MetraApiException catch (error) {
      expect(error.statusCode, 409);
      expect(
        error.displayMessage,
        anyOf(contains('تعارض'), contains('مسبقاً'), contains('مُرسلة')),
      );
    }
    api.close();
  });
}
