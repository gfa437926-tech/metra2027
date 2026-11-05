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

}
