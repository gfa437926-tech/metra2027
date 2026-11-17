import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/core/drafts/observation_draft_store.dart';
import 'package:metra_mobile/features/observations/phenomenon_observation_screen.dart';

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

  testWidgets('renders phenomenon form title and submit control', (tester) async {
    final api = apiWith((_) async => http.Response('{}', 200));
    await tester.pumpWidget(MaterialApp(
      home: PhenomenonObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    expect(find.text('بلاغ ظاهرة جوية'), findsOneWidget);
    expect(find.text('التحقق وإرسال بلاغ الظاهرة'), findsOneWidget);
    expect(find.byType(FilledButton), findsWidgets);
    api.close();
  });

  testWidgets('empty submit is blocked by local form validation before server call',
      (tester) async {
    var validateCalls = 0;
    var submitCalls = 0;
    final api = apiWith((request) async {
      if (request.url.path.endsWith('/phenomena/validate')) {
        validateCalls++;
      }
      if (request.url.path.contains('/stations/') &&
          request.url.path.endsWith('/observations')) {
        submitCalls++;
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(MaterialApp(
      home: PhenomenonObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();

    final submit = find.text('التحقق وإرسال بلاغ الظاهرة');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(validateCalls, 0);
    expect(submitCalls, 0);
    api.close();
  });

  Future<void> fillPhenomenon(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.ensureVisible(fields.at(0));
    await tester.enterText(fields.at(0), 'عاصفة رعدية');
    await tester.ensureVisible(fields.at(1));
    await tester.enterText(fields.at(1), '2026-11-17');
    await tester.ensureVisible(fields.at(2));
    await tester.enterText(fields.at(2), '10:00');
    await tester.ensureVisible(fields.at(3));
    await tester.enterText(fields.at(3), '11:30');
    final switches = find.byType(Switch);
    if (switches.evaluate().isNotEmpty) {
      await tester.ensureVisible(switches.last);
      await tester.tap(switches.last);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('successful phenomenon submit clears draft and shows success',
      (tester) async {
    var validateCalls = 0;
    var submitCalls = 0;
    final api = apiWith((request) async {
      if (request.url.path.contains('/validate')) {
        validateCalls++;
        return http.Response(jsonEncode({'isValid': true, 'issues': []}), 200);
      }
      if (request.url.path.contains('/observations')) {
        submitCalls++;
        return http.Response('{}', 201);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(MaterialApp(
      home: PhenomenonObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    await fillPhenomenon(tester);

    await tester.ensureVisible(find.text('التحقق وإرسال بلاغ الظاهرة'));
    await tester.tap(find.text('التحقق وإرسال بلاغ الظاهرة'));
    await tester.pumpAndSettle();

    expect(validateCalls, 1);
    expect(submitCalls, 1);
    expect(find.textContaining('أُرسل بلاغ الظاهرة'), findsOneWidget);
    expect(
      ObservationDraftStore.instance.get(stationId, 'phenomenon'),
      isNull,
    );
    api.close();
  });

  testWidgets('phenomenon shows loading label and blocks double submit',
      (tester) async {
    final gate = Completer<void>();
    var validateCalls = 0;
    final api = apiWith((request) async {
      if (request.url.path.contains('/validate')) {
        validateCalls++;
        await gate.future;
        return http.Response(jsonEncode({'isValid': true, 'issues': []}), 200);
      }
      return http.Response('{}', 201);
    });

    await tester.pumpWidget(MaterialApp(
      home: PhenomenonObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    await fillPhenomenon(tester);

    await tester.ensureVisible(find.text('التحقق وإرسال بلاغ الظاهرة'));
    await tester.tap(find.text('التحقق وإرسال بلاغ الظاهرة'));
    await tester.pump();
    expect(find.text('جارٍ الإرسال...'), findsWidgets);
    await tester.tap(find.text('جارٍ الإرسال...').first, warnIfMissed: false);
    await tester.pump();
    expect(validateCalls, 1);
    gate.complete();
    await tester.pumpAndSettle();
    api.close();
  });

  testWidgets('phenomenon 403 shows Arabic permission message and restores button',
      (tester) async {
    final api = apiWith((request) async {
      if (request.url.path.contains('/validate')) {
        return http.Response(jsonEncode({'isValid': true, 'issues': []}), 200);
      }
      return http.Response('forbidden', 403);
    });

    await tester.pumpWidget(MaterialApp(
      home: PhenomenonObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    await fillPhenomenon(tester);
    await tester.ensureVisible(find.text('التحقق وإرسال بلاغ الظاهرة'));
    await tester.tap(find.text('التحقق وإرسال بلاغ الظاهرة'));
    await tester.pumpAndSettle();

    expect(find.textContaining('صلاحية'), findsOneWidget);
    expect(find.text('التحقق وإرسال بلاغ الظاهرة'), findsOneWidget);
    api.close();
  });

  testWidgets('phenomenon 409 maps to conflict message', (tester) async {
    final api = apiWith((request) async {
      if (request.url.path.contains('/validate')) {
        return http.Response(jsonEncode({'isValid': true, 'issues': []}), 200);
      }
      return http.Response('{}', 409);
    });

    await tester.pumpWidget(MaterialApp(
      home: PhenomenonObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    await fillPhenomenon(tester);
    await tester.ensureVisible(find.text('التحقق وإرسال بلاغ الظاهرة'));
    await tester.tap(find.text('التحقق وإرسال بلاغ الظاهرة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعارض'), findsOneWidget);
    api.close();
  });

  testWidgets('screen mounts with bound submit control for operator flow',
      (tester) async {
    final api = apiWith((_) async => http.Response('forbidden', 403));
    await tester.pumpWidget(MaterialApp(
      home: PhenomenonObservationScreen(api: api, stationId: stationId),
    ));
    await tester.pumpAndSettle();
    expect(find.text('بلاغ ظاهرة جوية'), findsOneWidget);
    expect(find.text('التحقق وإرسال بلاغ الظاهرة'), findsOneWidget);
    api.close();
  });
}
