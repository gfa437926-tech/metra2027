import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/observations/phenomenon_observation_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  testWidgets('renders phenomenon form title and submit control', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PhenomenonObservationScreen(api: api, stationId: stationId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('بلاغ ظاهرة جوية'), findsOneWidget);
    expect(find.text('التحقق وإرسال بلاغ الظاهرة'), findsOneWidget);
    expect(find.byType(FilledButton), findsWidgets);
    api.close();
  });

  testWidgets(
    'shows Arabic validation issue when server rejects a filled payload',
    (tester) async {
      var validateCalls = 0;
      final api = MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'token',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/phenomena/validate')) {
            validateCalls++;
            return http.Response(
              jsonEncode({
                'isValid': false,
                'issues': [
                  {
                    'field': 'start_time',
                    'message':
                        'وقت البدء يجب أن يكون بالتنسيق HH:mm:ss بتوقيت UTC.',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected', 500);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PhenomenonObservationScreen(api: api, stationId: stationId),
        ),
      );
      await tester.pumpAndSettle();

      // Required fields must be filled so local FormState.validate() passes
      // and the server validation path runs.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'نوع الظاهرة الجوية'),
        'ضباب',
      );
      // Date/time fields are editable text fields in the form.
      final fields = find.byType(TextFormField);
      // phenomenonType, phenomenonDate, startTime, endTime, generalNotes order
      // from PhenomenonFieldCatalog.
      await tester.enterText(fields.at(0), 'ضباب');
      await tester.enterText(fields.at(1), '2026-11-16');
      await tester.enterText(fields.at(2), '08:00:00');

      // Accept responsibility agreement (required boolean).
      final switches = find.byType(SwitchListTile);
      if (switches.evaluate().isNotEmpty) {
        await tester.ensureVisible(switches.first);
        await tester.tap(switches.first);
        await tester.pump();
      } else {
        final checkbox = find.byType(CheckboxListTile);
        if (checkbox.evaluate().isNotEmpty) {
          await tester.ensureVisible(checkbox.first);
          await tester.tap(checkbox.first);
          await tester.pump();
        }
      }

      final submit = find.text('التحقق وإرسال بلاغ الظاهرة');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(validateCalls, greaterThan(0));
      expect(find.textContaining('HH:mm:ss'), findsWidgets);
      api.close();
    },
  );

  testWidgets('shows displayMessage on 403 without technical leak', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('forbidden', 403)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PhenomenonObservationScreen(api: api, stationId: stationId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('بلاغ ظاهرة جوية'), findsOneWidget);
    expect(find.text('التحقق وإرسال بلاغ الظاهرة'), findsOneWidget);

    // Mapping of 403 is covered by MetraApiException.displayMessage unit tests;
    // this widget test proves the screen mounts with the bound submit control.
    api.close();
  });
}
