import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/admin/authority_access_screen.dart';

void main() {
  testWidgets('authority access screen loads server catalogue, scoped queues and audit',
      (tester) async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.path + (request.url.hasQuery ? '?\${request.url.query}' : ''));
      if (request.url.path == '/api/v1/authorities') {
        return http.Response.bytes(
          utf8.encode(jsonEncode([
            {
              'id': 'authority-1',
              'authority_code': 'METRA-SY',
              'name_ar': 'الهيئة الوطنية للأرصاد',
              'name_en': 'National Meteorological Authority',
            },
          ])),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/access-audit')) {
        return http.Response('[]', 200);
      }
      if (request.url.path.endsWith('/access-queue')) {
        return http.Response('[]', 200);
      }
      return http.Response('not_found', 404);
    });
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'authority-access-token',
      client: client,
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthorityAccessScreen(api: api),
    ));
    await tester.pumpAndSettle();

    expect(find.text('إدارة العضويات والصلاحيات'), findsOneWidget);
    expect(find.text('الهيئة الوطنية للأرصاد'), findsOneWidget);
    expect(find.text('طلب عضوية لنفسي'), findsOneWidget);
    expect(find.text('طلب صلاحية'), findsOneWidget);
    expect(requested.any((path) => path.contains('kind=membership&limit=50')), isTrue);
    expect(requested.any((path) => path.contains('kind=permission_grant&limit=50')), isTrue);
    expect(requested.any((path) => path.endsWith('/access-audit?limit=100')), isTrue);

    await tester.tap(find.text('سجل التدقيق'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد أحداث تدقيق لهذه الجهة.'), findsOneWidget);
    api.close();
  });
}
