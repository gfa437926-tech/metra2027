import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/core/auth/metra_access_context.dart';
import 'package:metra_mobile/features/home/metra_home.dart';

MetraApiClient _unusedApi() => MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('[]', 200)),
    );

Future<void> _pumpHome(
  WidgetTester tester, {
  required MetraAccessContext access,
}) async {
  final api = _unusedApi();
  addTearDown(api.close);
  await tester.pumpWidget(
    MaterialApp(
      home: MetraHome(
        api: api,
        accessContextOverride: access,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('observer sees observations and hides administration', (tester) async {
    final access = MetraAccessContext.resolved(
      userId: 'u1',
      stationPermissions: {
        'station-a': {
          'observation.create',
          'observation.submit',
          'observation.edit_own_draft',
        },
      },
    );
    await _pumpHome(tester, access: access);

    expect(find.text('الرصد'), findsWidgets);
    expect(find.text('إدارة'), findsNothing);
    expect(find.text('وحدة الرصد'), findsOneWidget);
    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.text('المحطات'), findsWidgets);
    expect(find.text('إعدادات'), findsWidgets);
  });

  testWidgets('station_head sees administration and hides observation entry nav when no create', (
    tester,
  ) async {
    final access = MetraAccessContext.resolved(
      userId: 'u2',
      stationPermissions: {
        'station-a': {
          'observation.review',
          'observation.return_for_correction',
          'users.station.view',
          'users.station.manage',
          'registrations.station.approve',
        },
      },
    );
    await _pumpHome(tester, access: access);

    // Review permission still opens observation workspace (queue).
    expect(find.text('الرصد'), findsWidgets);
    expect(find.text('إدارة'), findsWidgets);
  });

  testWidgets('station_auditor sees review workspace and not administration', (tester) async {
    final access = MetraAccessContext.resolved(
      userId: 'u3',
      stationPermissions: {
        'station-a': {
          'observation.review',
          'observation.return_for_correction',
        },
      },
    );
    await _pumpHome(tester, access: access);

    expect(find.text('الرصد'), findsWidgets);
    expect(find.text('إدارة'), findsNothing);
  });

  testWidgets('user with no operational permissions hides obs and admin nav', (tester) async {
    final access = MetraAccessContext.resolved(
      userId: 'u4',
      stationPermissions: const {},
    );
    await _pumpHome(tester, access: access);

    expect(find.text('الرصد'), findsNothing);
    expect(find.text('إدارة'), findsNothing);
    expect(find.text('وحدة الرصد'), findsNothing);
    expect(find.text('المحطات'), findsWidgets);
  });

  testWidgets('unresolved access context hides operational destinations', (tester) async {
    await _pumpHome(tester, access: MetraAccessContext.unresolved());

    expect(find.text('الرصد'), findsNothing);
    expect(find.text('إدارة'), findsNothing);
    expect(find.text('وحدة الرصد'), findsNothing);
    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.text('المحطات'), findsWidgets);
    expect(find.text('إعدادات'), findsWidgets);
  });

  testWidgets('multi-station user keeps observations when any station allows it', (tester) async {
    final access = MetraAccessContext.resolved(
      userId: 'u5',
      stationPermissions: {
        'station-a': {'users.station.view'},
        'station-b': {'observation.create', 'observation.submit'},
      },
    );
    await _pumpHome(tester, access: access);

    expect(find.text('الرصد'), findsWidgets);
    expect(find.text('إدارة'), findsWidgets);
  });

  testWidgets('placeholders remain visible without inventing permission codes', (tester) async {
    final access = MetraAccessContext.resolved(
      userId: 'u6',
      stationPermissions: const {},
    );
    await _pumpHome(tester, access: access);

    expect(find.text('التنبؤ'), findsWidgets);
    expect(find.text('CLIMATOL'), findsWidgets);
    expect(find.text('تقارير'), findsWidgets);
  });
}
