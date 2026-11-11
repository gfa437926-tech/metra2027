import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/admin/station_assignment_screen.dart';

void main() {
  testWidgets('station assignment uses only server roles and submits a reasoned revoke',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var assignmentRequests = 0;
    var revokeRequests = 0;
    Map<String, dynamic>? assignmentBody;
    Map<String, dynamic>? revokeBody;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/stations/station-1/assignable-roles') {
        return http.Response.bytes(
          utf8.encode(jsonEncode([
            {'role_code': 'station_auditor', 'name_ar': 'مدقق محطة'},
          ])),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/stations/station-1/users') {
        return http.Response.bytes(
          utf8.encode(jsonEncode([
            {
              'assignment_id': 'assignment-1',
              'user_id': 'user-1',
              'role_code': 'station_auditor',
              'status': 'active',
            },
          ])),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/stations/station-1/assignments') {
        assignmentRequests++;
        assignmentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 201);
      }
      if (request.method == 'POST' &&
          request.url.path ==
              '/api/v1/stations/station-1/assignments/assignment-1/revoke') {
        revokeRequests++;
        revokeBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }
      return http.Response('not_found', 404);
    });
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'station-assignment-token',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(
      home: StationAssignmentScreen(api: api, stationId: 'station-1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('مدقق محطة'), findsOneWidget);
    expect(find.text('راصد'), findsNothing);
    expect(find.text('مدقق محطة'), findsOneWidget);

    await tester.tap(find.text('user-1'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل التعيين'), findsOneWidget);
    expect(find.textContaining('station_auditor'), findsOneWidget);
    await tester.tap(find.text('إغلاق'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'user-2');
    await tester.enterText(find.byType(TextField).at(1), 'تغطية مناوبة المحطة');
    final validTo = DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String();
    await tester.enterText(find.byType(TextField).at(2), validTo);
    await tester.pump();
    await tester.tap(find.text('طلب تعيين'));
    await tester.pumpAndSettle();

    expect(assignmentRequests, 1);
    expect(assignmentBody?['userId'], 'user-2');
    expect(assignmentBody?['roleCode'], 'station_auditor');
    expect(assignmentBody?['reason'], 'تغطية مناوبة المحطة');
    expect(DateTime.tryParse(assignmentBody?['validFrom'] as String)?.isUtc, isTrue);
    expect(assignmentBody?['validTo'], validTo);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'انتهاء الحاجة التشغيلية');
    await tester.tap(find.text('تأكيد الإلغاء'));
    await tester.pumpAndSettle();

    expect(revokeRequests, 1);
    expect(revokeBody?['reason'], 'انتهاء الحاجة التشغيلية');
    api.close();
  });
}
