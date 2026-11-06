import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/services/current_user_context_client.dart';

class _ThrowingTokenProvider implements AccessTokenProvider {
  @override
  Future<String?> getAccessToken() async =>
      throw StateError('secure session unavailable');
}

class _TokenProvider implements AccessTokenProvider {
  _TokenProvider(this.token);

  final String? token;

  @override
  Future<String?> getAccessToken() async => token;
}

String _contextJson(String state) => jsonEncode({
      'userId': 'metra-user-1',
      'profile': {
        'firstName': 'Test',
        'fatherName': null,
        'lastName': 'User',
        'email': null,
        'phone': null,
      },
      'accountState': state,
      'assignments': <dynamic>[],
      'permissions': <String>[],
    });

void main() {
  group('CurrentUserContextClient', () {
    test(
      'does not call the API while identity integration is disabled',
      () async {
        var requestCount = 0;
        final client = CurrentUserContextClient(
          client: MockClient((_) async {
            requestCount++;
            return http.Response('{}', 200);
          }),
          endpointEnabled: false,
        );

        final result = await client.load();

        expect(result.state, CurrentUserSessionState.unconfigured);
        expect(result.context, isNull);
        expect(requestCount, 0);
        client.close();
      },
    );

    test('fails closed when no access token is available', () async {
      final client = CurrentUserContextClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        tokenProvider: _TokenProvider(null),
        endpointEnabled: true,
      );

      final result = await client.load();

      expect(result.state, CurrentUserSessionState.unauthenticated);
      expect(result.context, isNull);
      client.close();
    });

    test('rejects a whitespace-only access token without calling the API', () async {
      var requestCount = 0;
      final client = CurrentUserContextClient(
        client: MockClient((_) async {
          requestCount++;
          return http.Response(_contextJson('Active'), 200);
        }),
        tokenProvider: _TokenProvider('   \t  '),
        endpointEnabled: true,
      );

      final result = await client.load();

      expect(result.state, CurrentUserSessionState.unauthenticated);
      expect(result.context, isNull);
      expect(requestCount, 0);
      client.close();
    });

    test('maps an active server account context', () async {
      final client = CurrentUserContextClient(
        client: MockClient(
          (_) async => http.Response(_contextJson('Active'), 200),
        ),
        tokenProvider: _TokenProvider('test-token'),
        endpointEnabled: true,
      );

      final result = await client.load();

      expect(result.state, CurrentUserSessionState.active);
      expect(result.context?.userId, 'metra-user-1');
      expect(result.context?.permissions, isEmpty);
      client.close();
    });

    test('does not treat an unknown account state as active', () async {
      final client = CurrentUserContextClient(
        client: MockClient(
          (_) async => http.Response(_contextJson('FutureState'), 200),
        ),
        tokenProvider: _TokenProvider('test-token'),
        endpointEnabled: true,
      );

      final result = await client.load();

      expect(result.state, CurrentUserSessionState.unknownAccountState);
      client.close();
    });

    test('maps unauthorized responses to an unauthenticated session', () async {
      final client = CurrentUserContextClient(
        client: MockClient((_) async => http.Response('{}', 401)),
        tokenProvider: _TokenProvider('expired-token'),
        endpointEnabled: true,
      );

      final result = await client.load();

      expect(result.state, CurrentUserSessionState.unauthenticated);
      expect(result.context, isNull);
      client.close();
    });

    test('sends the short-lived token only as a bearer authorization header', () async {
      http.Request? captured;
      final client = CurrentUserContextClient(
        client: MockClient((request) async {
          captured = request;
          return http.Response(_contextJson('Active'), 200);
        }),
        tokenProvider: _TokenProvider('short-lived-test-token'),
        endpointEnabled: true,
        baseUrl: 'https://api.example.test/api/v1/',
      );

      final result = await client.load();

      expect(result.state, CurrentUserSessionState.active);
      expect(captured?.method, 'GET');
      expect(captured?.url.toString(), 'https://api.example.test/api/v1/identity/me');
      expect(captured?.headers['Authorization'], 'Bearer short-lived-test-token');
      expect(captured?.headers['Accept'], 'application/json');
      client.close();
    });

    test('maps a forbidden identity context response to forbidden', () async {
      final client = CurrentUserContextClient(
        client: MockClient((_) async => http.Response('{}', 403)),
        tokenProvider: _TokenProvider('valid-token'),
        endpointEnabled: true,
      );

      final result = await client.load();

      expect(result.state, CurrentUserSessionState.forbidden);
      expect(result.context, isNull);
      client.close();
    });

    test('fails closed when the token provider throws', () async {
      final client = CurrentUserContextClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        tokenProvider: _ThrowingTokenProvider(),
        endpointEnabled: true,
      );

      final result = await client.load();

      expect(result.state, CurrentUserSessionState.unavailable);
      expect(result.context, isNull);
      client.close();
    });
  });
}
