import 'dart:async';
import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/reports/observation_archive_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';
  const observationId = '66666666-6666-4666-8666-666666666666';

  testWidgets('archive screen loads station records and opens source payload detail', (tester) async {
    final requestedPaths = <String>[];
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'archive-token',
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path.endsWith('/observation-archive')) {
          return http.Response(jsonEncode({
            'items': [{
              'id': observationId,
              'stationId': stationId,
              'sourceSystem': 'legacy-import',
              'sourceTable': 'hourly_records',
              'sourceRecordId': 'source-1',
              'observationType': 'hourly',
              'observedAtUtc': '2026-11-10T18:00:00Z',
              'payload': {'temperature': 24},
              'importedAtUtc': '2026-11-11T01:00:00Z'
            }],
            'hasMore': false,
            'nextCursor': null
          }), 200);
        }
        return http.Response(jsonEncode({
          'id': observationId,
          'stationId': stationId,
          'sourceSystem': 'legacy-import',
          'sourceTable': 'hourly_records',
          'sourceRecordId': 'source-1',
          'observationType': 'hourly',
          'observedAtUtc': '2026-11-10T18:00:00Z',
          'payload': {'temperature': 24},
          'importedAtUtc': '2026-11-11T01:00:00Z'
        }), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationArchiveScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('الأرشيف التاريخي للرصدات'), findsOneWidget);
    expect(find.text('رصد ساعي'), findsOneWidget);

    await tester.tap(find.text('رصد ساعي'));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل الرصد التاريخي'), findsOneWidget);
    expect(requestedPaths, contains(
      '/api/v1/stations/$stationId/observation-archive/$observationId',
    ));

    // The detail is a lazily built ListView. Scroll before searching for
    // widgets below the initial viewport; waiting/pump cannot build offscreen
    // sliver children.
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('محتوى الرصد الأصلي'), findsOneWidget);
    expect(find.textContaining('temperature'), findsOneWidget);
    api.close();
  });

  testWidgets('stale response from previous station is discarded after station switch', (tester) async {
    const secondStationId = '22222222-2222-4222-8222-222222222222';
    final firstResponse = Completer<http.Response>();
    final requestedStations = <String>[];
    var archiveRequestCount = 0;

    Map<String, dynamic> archiveResponse(String station, int temperature) => {
      'items': [{
        'id': observationId,
        'stationId': station,
        'sourceSystem': 'fixture',
        'sourceTable': 'hourly_records',
        'sourceRecordId': 'source-$temperature',
        'observationType': 'hourly',
        'observedAtUtc': '2026-11-10T18:00:00Z',
        'payload': {'temperature': temperature},
        'importedAtUtc': '2026-11-11T01:00:00Z'
      }],
      'hasMore': false,
      'nextCursor': null
    };

    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'archive-token',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/observation-archive')) {
          archiveRequestCount++;
          if (archiveRequestCount == 1) {
            requestedStations.add(stationId);
            return firstResponse.future;
          }
          requestedStations.add(secondStationId);
          return http.Response(jsonEncode(archiveResponse(secondStationId, 22)), 200);
        }
        return http.Response(jsonEncode({
          'id': observationId,
          'stationId': secondStationId,
          'sourceSystem': 'fixture',
          'sourceTable': 'hourly_records',
          'sourceRecordId': 'source-22',
          'observationType': 'hourly',
          'observedAtUtc': '2026-11-10T18:00:00Z',
          'payload': {'temperature': 22},
          'importedAtUtc': '2026-11-11T01:00:00Z'
        }), 200);
      }),
    );

    var selectedStation = stationId;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Column(
            children: [
              Expanded(child: ObservationArchiveScreen(
                api: api,
                stationId: selectedStation,
              )),
              TextButton(
                key: const Key('switch-station'),
                onPressed: () => setState(() => selectedStation = secondStationId),
                child: const Text('switch station'),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('switch-station')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(requestedStations, containsAll([stationId, secondStationId]));

    // Complete the old station request after the new station has loaded.
    firstResponse.complete(http.Response(
      jsonEncode(archiveResponse(stationId, 11)), 200));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.textContaining('"temperature": 22'), findsOneWidget);
    expect(find.textContaining('"temperature": 11'), findsNothing);
    api.close();
  });

  testWidgets('archive screen asks user to select a station before loading', (tester) async {
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationArchiveScreen(api: api, stationId: null)),
    ));
    expect(find.text('اختر محطة أولاً'), findsOneWidget);
    expect(find.textContaining('افتح دليل المحطات'), findsOneWidget);
    api.close();
  });
}
