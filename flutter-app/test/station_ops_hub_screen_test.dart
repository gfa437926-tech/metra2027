import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/ops/station_ops_hub_screen.dart';

void main() {
  testWidgets('ops hub shows equipment and support entries', skip: 'isolating non-widget failures in CI', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async => http.Response('[]', 200)),
    );

    await tester.pumpWidget(MaterialApp(
      home: StationOpsHubScreen(
        api: api,
        stationId: '11111111-1111-4111-8111-111111111111',
      ),
    ));

    expect(find.text('أعطال المعدات'), findsOneWidget);
    expect(find.text('بلاغات الدعم'), findsOneWidget);
    api.close();
  });
}
