import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/core/auth/metra_access_context.dart';
import 'package:metra_mobile/features/observations/observation_workspace_screen.dart';

MetraApiClient _api() => MetraApiClient(
  baseUrl: 'https://api.example.test',
  accessTokenProvider: () async => 'test-token',
  client: MockClient((_) async => http.Response('[]', 200)),
);

Future<void> _pump(WidgetTester tester, {MetraAccessContext? access}) async {
  final api = _api();
  addTearDown(api.close);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ObservationWorkspaceScreen(
          api: api,
          stationId: 'station-a',
          accessContext: access,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'unresolved or missing access context denies every workspace tab',
    (tester) async {
      await _pump(tester);

      expect(
        find.text(MetraPermissionDeniedMessages.contextUnavailable),
        findsOneWidget,
      );
      expect(find.text('ساعي · متصل'), findsNothing);
      expect(find.text('زراعي'), findsNothing);
      expect(find.text('مراجعة · متصل'), findsNothing);

      await _pump(tester, access: MetraAccessContext.unresolved());
      expect(
        find.text(MetraPermissionDeniedMessages.contextUnavailable),
        findsOneWidget,
      );
      expect(find.text('زراعي'), findsNothing);
    },
  );

  testWidgets('review-only user sees review tab but no data-entry forms', (
    tester,
  ) async {
    final access = MetraAccessContext.resolved(
      userId: 'reviewer',
      accountState: 'active',
      stationPermissions: {
        'station-a': {
          'observation.review',
          'observation.return_for_correction',
        },
      },
    );

    await _pump(tester, access: access);

    expect(find.text('مراجعة · متصل'), findsOneWidget);
    expect(find.text('ساعي · متصل'), findsNothing);
    expect(find.text('يومي · متصل'), findsNothing);
    expect(find.text('ظاهرة · متصل'), findsNothing);
    expect(find.text('زراعي'), findsNothing);
    expect(find.text('مناخي ساعي'), findsNothing);
    expect(find.text('أمطار'), findsNothing);
    expect(find.text('تربة'), findsNothing);
    expect(find.text('أعطال أجهزة'), findsNothing);
    expect(find.text('اتصالات'), findsNothing);
    expect(find.text('تقنية المعلومات'), findsNothing);
  });

  testWidgets('entry permission exposes connected and local catalogue tabs', (
    tester,
  ) async {
    final access = MetraAccessContext.resolved(
      userId: 'observer',
      accountState: 'active',
      stationPermissions: {
        'station-a': {'observation.create', 'observation.submit'},
      },
    );

    await _pump(tester, access: access);

    expect(find.text('ساعي · متصل'), findsOneWidget);
    expect(find.text('يومي · متصل'), findsOneWidget);
    expect(find.text('ظاهرة · متصل'), findsOneWidget);
    expect(find.text('زراعي'), findsOneWidget);
    expect(find.text('مناخي ساعي'), findsOneWidget);
    expect(find.text('أمطار'), findsOneWidget);
    expect(find.text('تربة'), findsOneWidget);
  });

  testWidgets('permission for another station does not expose this workspace', (
    tester,
  ) async {
    final access = MetraAccessContext.resolved(
      userId: 'other-station-user',
      accountState: 'active',
      stationPermissions: {
        'station-b': {'observation.create', 'observation.submit'},
      },
    );

    await _pump(tester, access: access);

    expect(
      find.text(MetraPermissionDeniedMessages.observations),
      findsOneWidget,
    );
    expect(find.text('ساعي · متصل'), findsNothing);
    expect(find.text('مراجعة · متصل'), findsNothing);
    expect(find.text('زراعي'), findsNothing);
  });

  testWidgets('unknown accountState denies workspace even with permission codes', (
    tester,
  ) async {
    final access = MetraAccessContext.resolved(
      userId: 'unknown-user',
      accountState: 'unknown',
      stationPermissions: {
        'station-a': {
          'observation.create',
          'observation.submit',
          'observation.review',
        },
      },
    );

    await _pump(tester, access: access);

    expect(
      find.text(MetraPermissionDeniedMessages.observations),
      findsOneWidget,
    );
    expect(find.text('ساعي · متصل'), findsNothing);
    expect(find.text('مراجعة · متصل'), findsNothing);
  });
}
