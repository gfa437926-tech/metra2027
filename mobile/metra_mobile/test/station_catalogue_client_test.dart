import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/station_catalogue.dart';
import 'current_user_context_client.dart';

enum StationCatalogueLoadState {
  unconfigured,
  unauthenticated,
  forbidden,
  unavailable,
  loaded,
}

class StationCatalogueResult {
  const StationCatalogueResult(this.state, {this.page});

  final StationCatalogueLoadState state;
  final StationCataloguePage? page;
}

class StationCatalogueClient {
  StationCatalogueClient({
    http.Client? client,
    AccessTokenProvider? tokenProvider,
    bool? endpointEnabled,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider,
        _endpointEnabled = endpointEnabled ?? ApiConfig.stationCatalogueEnabled,
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final AccessTokenProvider? _tokenProvider;
  final bool _endpointEnabled;
  final String _baseUrl;

  Future<StationCatalogueResult> loadPage({
    StationSourceKind? sourceKind,
    String? namePrefix,
    int pageSize = 50,
    String? cursor,
  }) async {
    if (!_endpointEnabled) {
      return const StationCatalogueResult(
          StationCatalogueLoadState.unconfigured);
    }
    if (pageSize < 1 ||
        pageSize > 100 ||
        (namePrefix != null &&
            (namePrefix.trim().isEmpty ||
                namePrefix.length > 128 ||
                namePrefix.codeUnits.any(
                    (unit) => unit < 32 || (unit >= 127 && unit <= 159)))) ||
        (cursor != null &&
            (cursor.isEmpty ||
                cursor.length > 2048 ||
                cursor.trim() != cursor))) {
      return const StationCatalogueResult(
          StationCatalogueLoadState.unavailable);
    }

    String? token;
    try {
      token = await _tokenProvider?.getAccessToken();
    } catch (_) {
      return const StationCatalogueResult(
          StationCatalogueLoadState.unavailable);
    }
    if (token == null || token.isEmpty) {
      return const StationCatalogueResult(
          StationCatalogueLoadState.unauthenticated);
    }

    try {
      final base = _baseUrl.endsWith('/')
          ? _baseUrl.substring(0, _baseUrl.length - 1)
          : _baseUrl;
      final query = <String, String>{'pageSize': '$pageSize'};
      if (sourceKind != null) query['sourceKind'] = sourceKind.name;
      if (namePrefix != null) query['namePrefix'] = namePrefix.trim();
      if (cursor != null) query['cursor'] = cursor;

      final uri = Uri.parse('$base/stations').replace(queryParameters: query);
      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
        'Authorization': '***',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return const StationCatalogueResult(
            StationCatalogueLoadState.unauthenticated);
      }
      if (response.statusCode == 403) {
        return const StationCatalogueResult(
            StationCatalogueLoadState.forbidden);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const StationCatalogueResult(
            StationCatalogueLoadState.unavailable);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const StationCatalogueResult(
            StationCatalogueLoadState.unavailable);
      }
      final page = StationCataloguePage.fromJson(
        decoded,
        requestedPageSize: pageSize,
        requestedCursor: cursor,
      );
      return StationCatalogueResult(StationCatalogueLoadState.loaded,
          page: page);
    } on TimeoutException {
      return const StationCatalogueResult(
          StationCatalogueLoadState.unavailable);
    } on FormatException {
      return const StationCatalogueResult(
          StationCatalogueLoadState.unavailable);
    } on TypeError {
      return const StationCatalogueResult(
          StationCatalogueLoadState.unavailable);
    } on http.ClientException {
      return const StationCatalogueResult(
          StationCatalogueLoadState.unavailable);
    }
  }

  void close() => _client.close();
}
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
