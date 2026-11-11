import 'dart:convert';

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

    await tester.tap(find.text('محطة دمشق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('محطة حمص'));
    await tester.pumpAndSettle();

    expect(find.text('المقارنة الجغرافية'), findsOneWidget);
    expect(find.text('مصدر الإحداثيات'), findsNWidgets(2));
    expect(find.text('survey'), findsOneWidget);
    expect(find.text('GPS'), findsOneWidget);
    expect(find.text('المسافة من المرجع'), findsNWidgets(2));
    expect(find.text('0 كم'), findsOneWidget);
    expect(find.textContaining('كم'), findsWidgets);

    // The reference selector is a real control; changing it must recalculate
    // which station is the zero-distance reference.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
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
}
