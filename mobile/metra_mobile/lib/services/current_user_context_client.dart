import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/current_user_context.dart';

enum CurrentUserSessionState {
  unconfigured,
  loading,
  unauthenticated,
  active,
  pendingApproval,
  suspended,
  forbidden,
  unavailable,
  unknownAccountState,
}

/// Supplies a short-lived OAuth access token from the platform secure-storage
/// session implementation. No local-storage or hard-coded token fallback exists.
abstract interface class AccessTokenProvider {
  Future<String?> getAccessToken();
}

class CurrentUserContextResult {
  const CurrentUserContextResult(this.state, {this.context});

  final CurrentUserSessionState state;
  final CurrentUserContext? context;
}

class CurrentUserContextClient {
  CurrentUserContextClient({
    http.Client? client,
    AccessTokenProvider? tokenProvider,
    bool? endpointEnabled,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider,
        _endpointEnabled = endpointEnabled ?? ApiConfig.identityContextEnabled,
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final AccessTokenProvider? _tokenProvider;
  final bool _endpointEnabled;
  final String _baseUrl;

  Future<CurrentUserContextResult> load() async {
    if (!_endpointEnabled) {
      return const CurrentUserContextResult(
        CurrentUserSessionState.unconfigured,
      );
    }

    String? token;
    try {
      token = await _tokenProvider?.getAccessToken();
    } catch (_) {
      return const CurrentUserContextResult(
        CurrentUserSessionState.unavailable,
      );
    }
    if (token == null || token.isEmpty) {
      return const CurrentUserContextResult(
        CurrentUserSessionState.unauthenticated,
      );
    }

    try {
      final base = _baseUrl.endsWith('/')
          ? _baseUrl.substring(0, _baseUrl.length - 1)
          : _baseUrl;
      final response = await _client.get(
        Uri.parse('$base/identity/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        return const CurrentUserContextResult(
          CurrentUserSessionState.unauthenticated,
        );
      }
      if (response.statusCode == 403) {
        return const CurrentUserContextResult(
          CurrentUserSessionState.forbidden,
        );
      }
      if (response.statusCode == 404) {
        return const CurrentUserContextResult(
          CurrentUserSessionState.unconfigured,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const CurrentUserContextResult(
          CurrentUserSessionState.unavailable,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const CurrentUserContextResult(
          CurrentUserSessionState.unavailable,
        );
      }

      final context = CurrentUserContext.fromJson(decoded);
      if (context.userId.trim().isEmpty) {
        return const CurrentUserContextResult(
          CurrentUserSessionState.unavailable,
        );
      }

      return CurrentUserContextResult(
        _mapAccountState(context.accountState),
        context: context,
      );
    } on FormatException {
      return const CurrentUserContextResult(
        CurrentUserSessionState.unavailable,
      );
    } on TypeError {
      return const CurrentUserContextResult(
        CurrentUserSessionState.unavailable,
      );
    } on http.ClientException {
      return const CurrentUserContextResult(
        CurrentUserSessionState.unavailable,
      );
    }
  }

  CurrentUserSessionState _mapAccountState(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return CurrentUserSessionState.active;
      case 'pendingstationapproval':
      case 'pendingsystemapproval':
      case 'pendingapproval':
        return CurrentUserSessionState.pendingApproval;
      case 'suspended':
      case 'disabled':
      case 'rejected':
        return CurrentUserSessionState.suspended;
      default:
        return CurrentUserSessionState.unknownAccountState;
    }
  }

  void close() => _client.close();
}
