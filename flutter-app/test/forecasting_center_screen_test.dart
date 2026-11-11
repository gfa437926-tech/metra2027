import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/forecasting/forecasting_center_screen.dart';

void main() {
  testWidgets('forecasting centre plots catalogue stations and compares coordinates/elevation',
      (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'forecast-test-token',
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/forecasting/compare') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['stationIds'], [
            '11111111-1111-4111-8111-111111111111',
            '22222222-2222-4222-8222-222222222222',
          ]);
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'stations': [
                {'stationId': '11111111-1111-4111-8111-111111111111'},
                {'stationId': '22222222-2222-4222-8222-222222222222'},
              ],
              'pairs': [
                {
                  'fromStationId': '11111111-1111-4111-8111-111111111111',
                  'toStationId': '22222222-2222-4222-8222-222222222222',
                  'distanceKm': 111.2,
                  'elevationDifferenceM': 300,
                },
              ],
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode([
          {
            'id': '11111111-1111-4111-8111-111111111111',
            'local_station_code': 'FC-01',
            'name_ar': 'محطة الشمال',
            'name_en': 'North station',
            'station_type': 'classic',
            'operational_status': 'active',
            'approval_status': 'approved',
            'is_demo': false,
            'elevation_m': 120,
            'station_coordinates': [
              {'latitude': 35.0, 'longitude': 36.0}
            ],
          },
          {
            'id': '22222222-2222-4222-8222-222222222222',
            'local_station_code': 'FC-02',
            'name_ar': 'محطة الجنوب',
            'name_en': 'South station',
            'station_type': 'automatic',
            'operational_status': 'active',
            'approval_status': 'approved',
            'is_demo': false,
            'elevation_m': 420,
            'station_coordinates': [
              {'latitude': 34.0, 'longitude': 36.0}
            ],
          },
        ])),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
        )),
      );
    }),
    );

    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      home: ForecastingCenterScreen(api: api),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('مركز التنبؤ الجوي'), findsOneWidget);
    expect(find.text('التوزع الجغرافي للمحطات'), findsOneWidget);
    expect(find.text('محطة الشمال'), findsOneWidget);
    expect(find.text('محطة الجنوب'), findsOneWidget);
    expect(find.textContaining('قيم الرصد اللحظية'), findsOneWidget);

    await tester.tap(find.text('محطة الشمال'));
    await tester.tap(find.text('محطة الجنوب'));
    await tester.tap(find.text('مقارنة المختارة'));
    await tester.pump();

    expect(find.text('نتائج المقارنة الجغرافية'), findsOneWidget);
    expect(find.text('محطة الشمال ↔ محطة الجنوب'), findsOneWidget);
    expect(find.textContaining('فرق الارتفاع: 300 م'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    api.close();
  });
}
