import 'dart:async';
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
      return const StationCatalogueResult(StationCatalogueLoadState.unconfigured);
    }
    if (pageSize < 1 || pageSize > 100 ||
        (namePrefix != null &&
          (namePrefix.trim().isEmpty || namePrefix.length > 128 ||
           namePrefix.codeUnits.any((unit) => unit < 32 || (unit >= 127 && unit <= 159)))) ||
        (cursor != null &&
          (cursor.isEmpty || cursor.length > 2048 || cursor.trim() != cursor))) {
      return const StationCatalogueResult(StationCatalogueLoadState.unavailable);
    }

    String? token;
    try {
      token = await _tokenProvider?.getAccessToken();
    } catch (_) {
      return const StationCatalogueResult(StationCatalogueLoadState.unavailable);
    }
    if (token == null || token.isEmpty) {
      return const StationCatalogueResult(StationCatalogueLoadState.unauthenticated);
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
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return const StationCatalogueResult(StationCatalogueLoadState.unauthenticated);
      }
      if (response.statusCode == 403) {
        return const StationCatalogueResult(StationCatalogueLoadState.forbidden);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const StationCatalogueResult(StationCatalogueLoadState.unavailable);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const StationCatalogueResult(StationCatalogueLoadState.unavailable);
      }
      final page = StationCataloguePage.fromJson(
        decoded,
        requestedPageSize: pageSize,
        requestedCursor: cursor,
      );
      return StationCatalogueResult(StationCatalogueLoadState.loaded, page: page);
    } on TimeoutException {
      return const StationCatalogueResult(StationCatalogueLoadState.unavailable);
    } on FormatException {
      return const StationCatalogueResult(StationCatalogueLoadState.unavailable);
    } on TypeError {
      return const StationCatalogueResult(StationCatalogueLoadState.unavailable);
    } on http.ClientException {
      return const StationCatalogueResult(StationCatalogueLoadState.unavailable);
    }
  }

  void close() => _client.close();
}
