import 'dart:convert';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/core/auth/metra_auth.dart';
import 'package:metra_mobile/features/stations/station_directory_screen.dart';
import 'package:metra_mobile/features/forecast_centres/forecast_centre_screen.dart';
import 'package:metra_mobile/core/widgets/metra_adaptive_navigation.dart';

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
          'elevation_m': 1150.0,
          'station_coordinates': [{'latitude': 24.7, 'longitude': 46.7, 'coordinate_source': 'surveyed', 'accuracy_m': 3.2}],
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
    await tester.tap(find.byTooltip('تفاصيل المحطة').first);
    await tester.pumpAndSettle();
    expect(find.text('الارتفاع عن سطح البحر'), findsOneWidget);
    expect(find.text('1150.0 م'), findsOneWidget);
    expect(find.text('surveyed'), findsOneWidget);
    expect(find.textContaining('لا تمثل قياسات جوية لحظية'), findsOneWidget);
    Navigator.of(tester.element(find.byType(StationDirectoryScreen))).pop();
    await tester.pumpAndSettle();
    final automaticStationTile = find.ancestor(
      of: find.text('محطة آلية'),
      matching: find.byType(ListTile),
    );
    await tester.tap(automaticStationTile);
    expect(selected, '22222222-2222-4222-8222-222222222222');
    api.close();
  });
  testWidgets('login exposes password recovery and validates email before request', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MetraLoginScreen()));
    expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
    await tester.tap(find.text('نسيت كلمة المرور؟'));
    await tester.pump();
    expect(find.text('أدخل البريد الإلكتروني أولاً لاستلام رابط الاستعادة.'), findsOneWidget);
  });


  testWidgets('shared navigation adapts between compact and wide layouts', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const destinations = [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
      NavigationDestination(icon: Icon(Icons.map_outlined), label: 'المحطات'),
    ];

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 800);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MetraAdaptiveNavigation(
          selectedIndex: 0,
          destinations: destinations,
          onDestinationSelected: (_) {},
          child: const Center(child: Text('محتوى الصفحة')),
        ),
      ),
    ));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });


  testWidgets('forecast centre compares station catalogue metadata without inventing live readings', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'test-token',
      client: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode([
        {
          'id': '11111111-1111-4111-8111-111111111111',
          'local_station_code': 'ST-01',
          'name_ar': 'محطة الساحل',
          'name_en': 'Coastal station',
          'station_type': 'synoptic',
          'operational_status': 'active',
          'approval_status': 'approved',
          'is_demo': false,
          'elevation_m': 25.0,
          'station_coordinates': [{'latitude': 35.5, 'longitude': 35.8, 'coordinate_source': 'surveyed', 'accuracy_m': 4.0}],
        },
        {
          'id': '22222222-2222-4222-8222-222222222222',
          'local_station_code': 'ST-02',
          'name_ar': 'محطة الجبل',
          'name_en': 'Mountain station',
          'station_type': 'classic',
          'operational_status': 'active',
          'approval_status': 'approved',
          'is_demo': false,
          'elevation_m': 1200.0,
          'station_coordinates': [{'latitude': 36.0, 'longitude': 36.2, 'coordinate_source': 'surveyed', 'accuracy_m': 5.0}],
        },
      ])), 200)),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ForecastCentreScreen(api: api)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('مراكز التنبؤ الجوي'), findsOneWidget);
    expect(find.text('الرصدات اللحظية والنشرات غير متصلة'), findsOneWidget);
    final firstChoice = find.byType(CheckboxListTile).at(0);
    await tester.ensureVisible(firstChoice);
    await tester.tap(firstChoice);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).at(0)).value, isTrue);
    final secondChoice = find.byType(CheckboxListTile).at(1);
    await tester.ensureVisible(secondChoice);
    await tester.tap(secondChoice);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).at(1)).value, isTrue);
    expect(find.text('المقارنة الجغرافية'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('1200.0 م'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('1200.0 م'), findsOneWidget);
    expect(find.text('المسافة من المرجع'), findsWidgets);
    api.close();
  });

}
