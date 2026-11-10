import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/core/auth/metra_auth.dart';
import 'package:metra_mobile/features/stations/station_directory_screen.dart';
import 'package:metra_mobile/features/home/metra_home.dart';

void main() {
  testWidgets('configuration screen explains missing secure environment values', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MetraConfigurationScreen()));
    expect(find.textContaining('إعداد تطبيق METRA 2027'), findsOneWidget);
    expect(find.textContaining('METRA_API_BASE_URL'), findsOneWidget);
    expect(find.textContaining('METRA_SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('service_role'), findsOneWidget);
  });

  testWidgets('station directory displays classic and automatic records together', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'test-token',
      client: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode([
        {
          'id': '11111111-1111-4111-8111-111111111111',
          'local_station_code': 'CL-01',
          'name_ar': 'محطة كلاسيكية',
          'name_en': 'Classic station',
          'station_type': 'classic',
          'operational_status': 'unverified',
          'approval_status': 'pending',
          'is_demo': false,
          'station_coordinates': [{'latitude': 24.7, 'longitude': 46.7}],
        },
        {
          'id': '22222222-2222-4222-8222-222222222222',
          'local_station_code': 'AU-01',
          'name_ar': 'محطة آلية',
          'name_en': 'Automatic station',
          'station_type': 'automatic',
          'operational_status': 'active',
          'approval_status': 'approved',
          'is_demo': false,
          'station_coordinates': [{'latitude': 25.1, 'longitude': 47.1}],
        },
      ])), 200)),
    );
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationDirectoryScreen(
          api: api,
          onStationSelected: (id) => selected = id,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('القائمة'));
    await tester.pumpAndSettle();
    expect(find.text('محطة كلاسيكية'), findsOneWidget);
    expect(find.text('محطة آلية'), findsOneWidget);
    await tester.tap(find.text('محطة آلية'));
    expect(selected, '22222222-2222-4222-8222-222222222222');
    api.close();
  });
  testWidgets('review navigation stays hidden until trusted scoped access exists', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'test-token',
      client: MockClient((_) async => http.Response('[]', 200)),
    );

    await tester.pumpWidget(MaterialApp(home: MetraHome(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('الرصد'), findsNothing);
    expect(find.text('مراجعة الرصدات'), findsNothing);
    expect(find.text('المحطات'), findsOneWidget);
    expect(find.text('التقارير'), findsOneWidget);

    api.close();
  });
}
