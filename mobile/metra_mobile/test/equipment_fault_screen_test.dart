import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/maintenance/equipment_fault_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  testWidgets('loads equipment fault queue from API', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.contains('/equipment-faults')) {
          return http.Response(
            jsonEncode([
              {
                'id': '22222222-2222-4222-8222-222222222222',
                'equipment_name': 'مقياس الحرارة',
                'equipment_category': 'أجهزة الرصد',
                'severity': 'High',
                'status': 'Submitted',
                'description': 'توقف عن الإرسال',
              }
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: EquipmentFaultScreen(api: api, stationId: stationId),
    ));
    await tester.pump(); // start future
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('أعطال المعدات'), findsOneWidget);
    expect(find.textContaining('مقياس الحرارة'), findsOneWidget);
    api.close();
  });
}
