import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/ops/station_ops_hub_screen.dart';

void main() {
  testWidgets('ops hub shows equipment and support entries', (tester) async {
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
    await tester.scrollUntilVisible(
      find.text('بلاغات الدعم'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('بلاغات الدعم'), findsOneWidget);
    api.close();
  });
}
