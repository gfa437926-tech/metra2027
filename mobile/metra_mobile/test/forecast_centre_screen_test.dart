import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/forecast_centres/forecast_centre_screen.dart';

void main() {
  testWidgets('forecast centre compares selected stations using catalogue provenance',
      (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'forecast-token',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/stations');
        expect(request.url.queryParameters['limit'], '500');
        return http.Response(
          jsonEncode([
            {
              'id': '11111111-1111-4111-8111-111111111111',
              'local_station_code': 'ST001',
              'name_ar': 'محطة دمشق',
              'name_en': 'Damascus',
              'station_type': 'classic',
              'operational_status': 'active',
              'approval_status': 'approved',
              'is_demo': false,
              'elevation_m': 700,
              'station_coordinates': [
                {
                  'latitude': 33.5138,
                  'longitude': 36.2765,
                  'coordinate_source': 'survey',
                  'accuracy_m': 5
                }
              ]
            },
            {
              'id': '22222222-2222-4222-8222-222222222222',
              'local_station_code': 'ST002',
              'name_ar': 'محطة حمص',
              'name_en': 'Homs',
              'station_type': 'automatic',
              'operational_status': 'active',
              'approval_status': 'approved',
              'is_demo': false,
              'elevation_m': 500,
              'station_coordinates': [
                {
                  'latitude': 34.7308,
                  'longitude': 36.7094,
                  'coordinate_source': 'GPS',
                  'accuracy_m': 3.5
                }
              ]
            },
            {
              'id': '33333333-3333-4333-8333-333333333333',
              'local_station_code': 'ST003',
              'name_ar': 'محطة بلا إحداثيات',
              'name_en': 'No coordinates',
              'station_type': 'synoptic',
              'operational_status': 'active',
              'approval_status': 'approved',
              'is_demo': false,
              'elevation_m': null,
              'station_coordinates': []
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ForecastCentreScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مراكز التنبؤ الجوي'), findsOneWidget);
    expect(find.text('الرصدات اللحظية والنشرات غير متصلة'), findsOneWidget);
    expect(find.text('محطة دمشق'), findsOneWidget);
    expect(find.text('محطة حمص'), findsOneWidget);

    // Tap the complete selectable tiles, as a user does, rather than the
    // nested title Text widget whose hit target is not the tile contract.
    final damascusTile = find.byType(CheckboxListTile).at(0);
    await tester.ensureVisible(damascusTile);
    await tester.tap(damascusTile);
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(damascusTile).value,
      isTrue,
    );

    final homsTile = find.byType(CheckboxListTile).at(1);
    await tester.ensureVisible(homsTile);
    await tester.tap(homsTile);
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(homsTile).value,
      isTrue,
    );

    expect(find.text('المقارنة الجغرافية'), findsOneWidget);
    // Comparison cards sit below the selection list in a scrollable; ensure
    // lazy ListView children are built before provenance assertions.
    await tester.scrollUntilVisible(
      find.text('مصدر الإحداثيات').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('مصدر الإحداثيات'), findsWidgets);
    expect(find.text('survey'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('GPS'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('GPS'), findsOneWidget);
    expect(find.text('المسافة من المرجع'), findsWidgets);
    expect(find.text('0 كم'), findsOneWidget);
    expect(find.textContaining('كم'), findsWidgets);

    // The reference selector is a real control; changing it must recalculate
    // which station is the zero-distance reference.
    // Scroll to the selector by its visible label. A fixed drag distance is
    // brittle because the preceding provenance assertions may leave the list
    // at different offsets across Flutter engine versions.
    final referenceLabel = find.text('المحطة المرجعية لحساب المسافات');
    await tester.scrollUntilVisible(
      referenceLabel,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final referencePicker = find.byType(DropdownButtonFormField);
    expect(referencePicker, findsOneWidget);
    await tester.tap(referencePicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('محطة حمص').last);
    await tester.pumpAndSettle();
    expect(find.text('مرجع المقارنة'), findsOneWidget);
    expect(find.text('0 كم'), findsOneWidget);

    api.close();
  });

  testWidgets('forecast centre reports a permission-specific load failure',
      (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'forecast-token',
      client: MockClient((_) async => http.Response(
            jsonEncode({'error': 'forbidden'}),
            403,
            headers: {'content-type': 'application/json'},
          )),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ForecastCentreScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحميل دليل المحطات'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);

    api.close();
  });

  testWidgets('forecast centre rejects stations beyond four and flags missing coordinates',
      (tester) async {
    final stationRows = List.generate(5, (index) {
      final number = index + 1;
      return {
        'id': '0000000$number-0000-4000-8000-00000000000$number',
        'local_station_code': 'FC00$number',
        'name_ar': 'محطة اختبار $number',
        'name_en': 'Test station $number',
        'station_type': 'classic',
        'operational_status': 'active',
        'approval_status': 'approved',
        'is_demo': false,
        'elevation_m': number == 4 ? null : 100 * number,
        'station_coordinates': number == 4
            ? <Map<String, dynamic>>[]
            : [
                {
                  'latitude': 30.0 + number,
                  'longitude': 35.0 + number,
                  'coordinate_source': 'fixture',
                  'accuracy_m': 10
                }
              ],
      };
    });
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'forecast-token',
      client: MockClient((_) async => http.Response(
            jsonEncode(stationRows),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ForecastCentreScreen(api: api)),
    ));
    await tester.pumpAndSettle();

    for (var index = 1; index <= 4; index++) {
      final choice = find.text('محطة اختبار $index');
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
    }

    final fifthChoice = find.ancestor(
      of: find.text('محطة اختبار 5'),
      matching: find.byType(CheckboxListTile),
    );
    await tester.ensureVisible(fifthChoice);
    expect(tester.widget<CheckboxListTile>(fifthChoice).onChanged, isNull);

    await tester.scrollUntilVisible(
      find.text('غير قابلة للحساب — الإحداثيات غير صالحة'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('غير قابلة للحساب — الإحداثيات غير صالحة'), findsOneWidget);

    api.close();
  });
}
