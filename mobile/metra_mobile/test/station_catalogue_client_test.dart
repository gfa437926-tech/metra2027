import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/models/station_catalogue.dart';
import 'package:metra_mobile/services/current_user_context_client.dart';
import 'package:metra_mobile/services/station_catalogue_client.dart';

class _TokenProvider implements AccessTokenProvider {
  _TokenProvider(this.token);
  final String? token;

  @override
  Future<String?> getAccessToken() async => token;
}

Map<String, dynamic> _station({
  int sourceKind = 0,
  String id = 'classic-1',
  String name = 'محطة اختبار',
  double? latitude = 33.5,
  double? longitude = 36.3,
}) =>
    {
      'sourceKind': sourceKind,
      'sourceRecordId': id,
      'displayName': name,
      'sourceStationType': null,
      'sourceCode': 'T-1',
      'latitude': latitude,
      'longitude': longitude,
      'elevationMetres': null,
    };

void main() {
  group('StationCatalogueClient', () {
    test('does not call the API while endpoint is disabled', () async {
      var calls = 0;
      final client = StationCatalogueClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
        endpointEnabled: false,
      );

      final result = await client.loadPage();
      expect(result.state, StationCatalogueLoadState.unconfigured);
      expect(calls, 0);
      client.close();
    });

    test('fails closed without a bearer token', () async {
      final client = StationCatalogueClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        tokenProvider: _TokenProvider(null),
        endpointEnabled: true,
      );

      final result = await client.loadPage();
      expect(result.state, StationCatalogueLoadState.unauthenticated);
      client.close();
    });

    test('loads both source kinds without merging equal display names',
        () async {
      final client = StationCatalogueClient(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/stations');
          expect(request.headers['authorization'], '***');
          expect(request.url.queryParameters['pageSize'], '50');
          return http.Response(
              jsonEncode({
                'items': [
                  _station(),
                  _station(
                      sourceKind: 1,
                      id: 'automatic-1',
                      latitude: null,
                      longitude: null),
                ],
                'hasMore': false,
                'nextCursor': null,
              }),
              200);
        }),
        tokenProvider: _TokenProvider('test-token'),
        endpointEnabled: true,
        baseUrl: 'https://api.example.test/api/v1',
      );

      final result = await client.loadPage();
      expect(result.state, StationCatalogueLoadState.loaded);
      expect(result.page!.items.length, 2);
      expect(result.page!.items[0].sourceKind, StationSourceKind.classic);
      expect(result.page!.items[1].sourceKind, StationSourceKind.automatic);
      expect(
          result.page!.items[0].displayName, result.page!.items[1].displayName);
      expect(result.page!.items[1].hasCoordinates, isFalse);
      client.close();
    });

    test('preserves cursor and source filters on page requests', () async {
      final client = StationCatalogueClient(
        client: MockClient((request) async {
          expect(request.url.queryParameters['sourceKind'], 'automatic');
          expect(request.url.queryParameters['cursor'], 'next-page');
          return http.Response(
              jsonEncode({
                'items': [_station(sourceKind: 1, id: 'automatic-2')],
                'hasMore': false,
                'nextCursor': null,
              }),
              200);
        }),
        tokenProvider: _TokenProvider('test-token'),
        endpointEnabled: true,
        baseUrl: 'https://api.example.test/api/v1',
      );

      final result = await client.loadPage(
        sourceKind: StationSourceKind.automatic,
        cursor: 'next-page',
      );
      expect(result.state, StationCatalogueLoadState.loaded);
      client.close();
    });

    test('rejects partial coordinate pairs and repeated source identities',
        () async {
      final partial = _station(latitude: 33.5, longitude: null);
      expect(
        () => StationCatalogueItem.fromJson(partial),
        throwsFormatException,
      );

      final duplicate = {
        'items': [_station(), _station()],
        'hasMore': false,
        'nextCursor': null,
      };
      expect(
        () => StationCataloguePage.fromJson(duplicate, requestedPageSize: 50),
        throwsFormatException,
      );
    });

    test('maps forbidden and unavailable responses without exposing body',
        () async {
      final forbidden = StationCatalogueClient(
        client: MockClient((_) async => http.Response('secret', 403)),
        tokenProvider: _TokenProvider('test-token'),
        endpointEnabled: true,
      );
      expect((await forbidden.loadPage()).state,
          StationCatalogueLoadState.forbidden);
      forbidden.close();

      final unavailable = StationCatalogueClient(
        client: MockClient((_) async => http.Response('secret', 503)),
        tokenProvider: _TokenProvider('test-token'),
        endpointEnabled: true,
      );
      expect((await unavailable.loadPage()).state,
          StationCatalogueLoadState.unavailable);
      unavailable.close();
    });
  });
}
