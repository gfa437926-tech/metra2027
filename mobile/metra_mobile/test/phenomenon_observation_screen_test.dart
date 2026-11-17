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
      if (request.url.path.endsWith('/phenomena/validate')) validateCalls++;
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
