import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:metra_mobile/features/observations/hourly_observation_screen.dart';
import 'package:metra_mobile/services/observation_validation_client.dart';

void main() {
  testWidgets('shows conditional synoptic and precipitation fields at 00 UTC',
      (tester) async {
    final client = MockClient((request) async => http.Response(
          '{"isValid":true,"issues":[]}',
          200,
          headers: {'content-type': 'application/json'},
        ));
    await tester.pumpWidget(MaterialApp(
      home: HourlyObservationScreen(
        validationClient: ObservationValidationClient(
          client: client,
          baseUrl: 'https://example.test/api/v1',
        ),
      ),
    ));

    await tester.scrollUntilVisible(find.text('ميل الضغط'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('ميل الضغط'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('شكل تغير الضغط'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('شكل تغير الضغط'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('الطقس السابق'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('الطقس السابق'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('كمية الهطول'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('كمية الهطول'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('التحقق من النشرة'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('التحقق من النشرة'), findsOneWidget);
  });

  testWidgets('blocks an empty form before calling the validation API',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('{"isValid":true,"issues":[]}', 200);
    });
    await tester.pumpWidget(MaterialApp(
      home: HourlyObservationScreen(
        validationClient: ObservationValidationClient(
          client: client,
          baseUrl: 'https://example.test/api/v1',
        ),
      ),
    ));

    final submitButton = find.byType(FilledButton);
    await tester.scrollUntilVisible(submitButton, 250, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(requests, 0);
    expect(find.text('هذا الحقل مطلوب'), findsWidgets);
  });
  testWidgets('reset clears entered values and validation feedback',
      (tester) async {
    final client = MockClient((request) async =>
        http.Response('{"isValid":true,"issues":[]}', 200));
    await tester.pumpWidget(MaterialApp(
      home: HourlyObservationScreen(
        validationClient: ObservationValidationClient(
          client: client,
          baseUrl: 'https://example.test/api/v1',
        ),
      ),
    ));

    final dryTemperature = find.byType(TextFormField).first;
    await tester.enterText(dryTemperature, '+21.0');
    await tester.scrollUntilVisible(find.text('تفريغ'), 250, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('تفريغ'));
    await tester.tap(find.text('تفريغ'), warnIfMissed: false);
    await tester.pump();

    final field = tester.widget<TextFormField>(dryTemperature);
    expect(field.controller!.text, isEmpty);
    expect(find.text('تفريغ'), findsOneWidget);
    expect(find.textContaining('اجتازت التحقق'), findsNothing);
  });

  testWidgets('keeps submission disabled when no secure token provider exists',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HourlyObservationScreen(),
    ));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('submit-hourly-observation')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('submit-hourly-observation')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('الإرسال غير مفعّل: لم يتم ربط مزوّد جلسة دخول آمن بهذه الشاشة.'),
      findsOneWidget,
    );
  });

  testWidgets('enables submission only when a token provider is injected',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HourlyObservationScreen(
        accessTokenProvider: () async => 'short-lived-test-token',
      ),
    ));

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('submit-hourly-observation')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('submit-hourly-observation')),
    );
    expect(button.onPressed, isNotNull);
    expect(
      find.text(
        'يتم التحقق أولاً ثم الإرسال إلى .NET. تعتمد صلاحية المحطة على هوية المستخدم في الخادم.',
      ),
      findsOneWidget,
    );
  });


  testWidgets('locks observation inputs while validation is in flight',
      (tester) async {
    final response = Completer<http.Response>();
    final client = MockClient((request) => response.future);
    await tester.pumpWidget(MaterialApp(
      home: HourlyObservationScreen(
        validationClient: ObservationValidationClient(
          client: client,
          baseUrl: 'https://example.test/api/v1',
        ),
      ),
    ));

    final fields = find.byType(TextFormField);
    for (var i = 0; i < 12; i++) {
      await tester.enterText(fields.at(i), '1');
    }

    final validateButton = find.widgetWithText(FilledButton, 'التحقق من النشرة');
    await tester.scrollUntilVisible(
      validateButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(validateButton);
    await tester.pump();

    expect(tester.widget<TextFormField>(fields.first).enabled, isFalse);
    final dateButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, RegExp('تاريخ الرصد:')),
    );
    expect(dateButton.onPressed, isNull);
    final hourPicker = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(hourPicker.onChanged, isNull);

    response.complete(http.Response('{"isValid":true,"issues":[]}', 200));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(fields.first).enabled, isTrue);
  });

}

  testWidgets('keeps form locked while token and submit requests are pending',
      (tester) async {
    final tokenResponse = Completer<String?>();
    final submitResponse = Completer<http.Response>();
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      if (request.url.path.endsWith('/validate')) {
        return http.Response('{"isValid":true,"issues":[]}', 200);
      }
      return submitResponse.future;
    });
    await tester.pumpWidget(MaterialApp(
      home: HourlyObservationScreen(
        validationClient: ObservationValidationClient(
          client: client,
          baseUrl: 'https://example.test/api/v1',
        ),
        accessTokenProvider: () => tokenResponse.future,
      ),
    ));

    final fields = find.byType(TextFormField);
    for (var i = 0; i < 12; i++) {
      await tester.enterText(fields.at(i), '1');
    }

    final submitButton = find.byKey(
      const ValueKey('submit-hourly-observation'),
    );
    await tester.scrollUntilVisible(
      submitButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(requests, 1);
    expect(tester.widget<TextFormField>(fields.first).enabled, isFalse);

    tokenResponse.complete('short-lived-test-token');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(requests, 2);
    expect(tester.widget<TextFormField>(fields.first).enabled, isFalse);
    expect(
      tester.widget<OutlinedButton>(submitButton).onPressed,
      isNull,
    );

    submitResponse.complete(http.Response(
      '{"observationId":"obs-123","stationId":"station-456","status":"submitted"}',
      201,
      headers: {'content-type': 'application/json'},
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.widget<TextFormField>(fields.first).enabled, isTrue);
    expect(
      tester.widget<OutlinedButton>(submitButton).onPressed,
      isNotNull,
    );
    expect(find.textContaining('obs-123'), findsOneWidget);
  });

