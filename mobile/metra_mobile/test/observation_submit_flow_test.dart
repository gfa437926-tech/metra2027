import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/core/drafts/observation_draft_store.dart';
import 'package:metra_mobile/core/observations/observation_submit_flow.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';

  setUp(() {
    ObservationDraftStore.instance.clearAll();
  });

  MetraApiClient clientWith(MockClientHandler handler) => MetraApiClient(
    baseUrl: 'https://api.example.test',
    accessTokenProvider: () async => 'token',
    client: MockClient(handler),
    requestTimeout: const Duration(seconds: 5),
  );

  test('successful validate+submit clears draft and returns success', () async {
    ObservationDraftStore.instance.save(
      stationId: stationId,
      formType: 'hourly',
      values: {'temp': 20},
    );
    final api = clientWith((request) async {
      if (request.url.path.contains('/validate')) {
        return http.Response(
          jsonEncode({'isValid': true, 'issues': <Object>[]}),
          200,
        );
      }
      if (request.url.path.contains('/observations')) {
        return http.Response(
          jsonEncode({'id': 'obs-1', 'status': 'submitted'}),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    final flow = ObservationSubmitFlow(api: api);
    final outcome = await flow.validateAndSubmit(
      formType: 'hourly',
      stationId: stationId,
      values: {'temp': 20},
      successMessageAr: 'تم',
      validationFallbackAr: 'فشل',
    );
    expect(outcome.succeeded, isTrue);
    expect(outcome.clearedDraft, isTrue);
    expect(
      ObservationDraftStore.instance.hasDraft(stationId, 'hourly'),
      isFalse,
    );
    api.close();
  });

  test('invalid validation keeps draft and returns failure', () async {
    ObservationDraftStore.instance.save(
      stationId: stationId,
      formType: 'daily',
      values: {'x': 1},
    );
    final api = clientWith((request) async {
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'isValid': false,
            'issues': [
              {'field': 'x', 'message': 'حقل ناقص'},
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final flow = ObservationSubmitFlow(api: api);
    final outcome = await flow.validateAndSubmit(
      formType: 'daily',
      stationId: stationId,
      values: {'x': 1},
      successMessageAr: 'تم',
      validationFallbackAr: 'فشل',
    );
    expect(outcome.succeeded, isFalse);
    expect(outcome.messageAr, 'حقل ناقص');
    expect(ObservationDraftStore.instance.hasDraft(stationId, 'daily'), isTrue);
    api.close();
  });

  test('auth failure maps to Arabic message without clearing draft', () async {
    ObservationDraftStore.instance.save(
      stationId: stationId,
      formType: 'hourly',
      values: {'temp': 1},
    );
    final api = clientWith((request) async {
      return http.Response('{}', 401);
    });
    final flow = ObservationSubmitFlow(api: api);
    final outcome = await flow.validateAndSubmit(
      formType: 'hourly',
      stationId: stationId,
      values: {'temp': 1},
      successMessageAr: 'تم',
      validationFallbackAr: 'فشل',
    );
    expect(outcome.succeeded, isFalse);
    expect(
      outcome.messageAr.contains('الجلسة') ||
          outcome.messageAr.contains('الدخول'),
      isTrue,
    );
    expect(
      ObservationDraftStore.instance.hasDraft(stationId, 'hourly'),
      isTrue,
    );
    api.close();
  });

  test('idempotency key reused for identical payload retry', () async {
    var submitCount = 0;
    String? firstKey;
    String? secondKey;
    final api = clientWith((request) async {
      if (request.url.path.contains('/validate')) {
        return http.Response(
          jsonEncode({'isValid': true, 'issues': <Object>[]}),
          200,
        );
      }
      if (request.url.path.contains('/observations')) {
        submitCount += 1;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final key =
            body['idempotency_key']?.toString() ??
            body['idempotencyKey']?.toString();
        if (submitCount == 1) {
          firstKey = key;
          return http.Response('timeout', 504);
        }
        secondKey = key;
        return http.Response(
          jsonEncode({'id': 'obs-2', 'status': 'submitted'}),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    final flow = ObservationSubmitFlow(api: api);
    final values = {'temp': 21};
    final first = await flow.validateAndSubmit(
      formType: 'hourly',
      stationId: stationId,
      values: values,
      successMessageAr: 'تم',
      validationFallbackAr: 'فشل',
    );
    expect(first.succeeded, isFalse);
    final second = await flow.validateAndSubmit(
      formType: 'hourly',
      stationId: stationId,
      values: values,
      successMessageAr: 'تم',
      validationFallbackAr: 'فشل',
    );
    expect(second.succeeded, isTrue);
    expect(firstKey, isNotNull);
    expect(secondKey, firstKey);
    api.close();
  });

  test('idempotency key is not reused across station or form scope', () async {
    final keys = <String>[];
    final api = clientWith((request) async {
      if (request.url.path.contains('/validate')) {
        return http.Response(
          jsonEncode({'isValid': true, 'issues': <Object>[]}),
          200,
        );
      }
      if (request.url.path.contains('/observations')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        keys.add(
          body['idempotency_key']?.toString() ??
              body['idempotencyKey']?.toString() ??
              '',
        );
        return http.Response('gateway timeout', 504);
      }
      return http.Response('not found', 404);
    });
    final flow = ObservationSubmitFlow(api: api);
    Future<void> attempt(String type, String station) async {
      await flow.validateAndSubmit(
        formType: type,
        stationId: station,
        values: const {'temp': 21},
        successMessageAr: 'تم',
        validationFallbackAr: 'فشل',
      );
    }
    await attempt('hourly', stationId);
    await attempt('daily', stationId);
    await attempt('hourly', '22222222-2222-4222-8222-222222222222');
    expect(keys, hasLength(3));
    expect(keys.toSet(), hasLength(3));
    api.close();
  });

}
