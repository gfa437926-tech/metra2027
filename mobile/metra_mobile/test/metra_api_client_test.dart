import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/api_config.dart';

void main() {
  test('access context parses authority permissions without station scope leakage', () async {
    late http.Request captured;
    const authorityId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const stationId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'authority-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'userId': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
            'accountState': 'active',
            'stations': [
              {
                'stationId': stationId,
                'roleCode': 'observer',
                'permissions': ['observation.create'],
              },
            ],
            'authorities': [
              {
                'authorityId': authorityId,
                'roleCode': 'system_reviewer',
                'permissions': ['stations.catalogue.review', 'authority.access.review'],
              },
            ],
          }),
          200,
        );
      }),
    );

    final context = await client.getAccessContext();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/me/access-context');
    expect(captured.headers['authorization'], 'Bearer authority-token');
    expect(context.hasKnownActiveAccount, isTrue);
    expect(context.hasAuthorityPermission(authorityId, 'authority.access.review'), isTrue);
    expect(context.hasAuthorityPermission(stationId, 'authority.access.review'), isFalse);
    expect(context.hasStationPermission(stationId, 'observation.create'), isTrue);
    expect(context.hasStationPermission(authorityId, 'observation.create'), isFalse);
    expect(context.authorityRoles[authorityId], 'system_reviewer');
    client.close();
  });

  test('access context accepts snake case authority fields and ignores malformed entries', () async {
    const authorityId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'snake-case-token',
      client: MockClient((request) async => http.Response(
        jsonEncode({
          'user_id': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
          'account_state': 'active',
          'stations': [
            null,
            {'station_id': '', 'permissions': ['observation.create']},
          ],
          'authorities': [
            null,
            {'authority_id': '', 'permissions': ['authority.access.review']},
            {
              'authority_id': authorityId,
              'role_code': 'system_reviewer',
              'permissions': ['authority.access.review', '', null],
            },
          ],
        }),
        200,
      )),
    );

    final context = await client.getAccessContext();

    expect(context.userId, 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
    expect(context.accountState, 'active');
    expect(context.hasKnownActiveAccount, isTrue);
    expect(context.authorityRoles[authorityId], 'system_reviewer');
    expect(context.hasAuthorityPermission(authorityId, 'authority.access.review'), isTrue);
    expect(context.hasAuthorityPermission('', 'authority.access.review'), isFalse);
    expect(context.stationPermissions, isEmpty);
    expect(context.authorityPermissions[authorityId], {'authority.access.review'});
    client.close();
  });

  test('access context with unknown accountState parses but grants no operational permissions', () async {
    const authorityId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const stationId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'unknown-token',
      client: MockClient((request) async => http.Response(
        jsonEncode({
          'userId': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          'accountState': 'unknown',
          'stations': [
            {
              'stationId': stationId,
              'roleCode': 'observer',
              'permissions': ['observation.create'],
            },
          ],
          'authorities': [
            {
              'authorityId': authorityId,
              'roleCode': 'system_reviewer',
              'permissions': ['authority.access.review'],
            },
          ],
        }),
        200,
      )),
    );

    final context = await client.getAccessContext();

    expect(context.isResolved, isTrue);
    expect(context.accountState, 'unknown');
    expect(context.hasKnownActiveAccount, isFalse);
    expect(context.hasStationPermission(stationId, 'observation.create'), isFalse);
    expect(context.hasAuthorityPermission(authorityId, 'authority.access.review'), isFalse);
    expect(context.canEnterObservations(stationId), isFalse);
    client.close();
  });

  test('access context ignores non-string identifiers, roles and permissions', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'typed-contract-token',
      client: MockClient((request) async => http.Response(
        jsonEncode({
          'userId': 'typed-user',
          'accountState': 'active',
          'stations': [
            {
              'stationId': 123,
              'roleCode': 7,
              'permissions': [1, true, 'observation.create'],
            },
            {
              'stationId': 'station-valid',
              'roleCode': 9,
              'permissions': [42, 'observation.submit'],
            },
          ],
          'authorities': [
            {
              'authorityId': 456,
              'roleCode': 8,
              'permissions': [1, 'authority.access.review'],
            },
            {
              'authorityId': 'authority-valid',
              'roleCode': false,
              'permissions': [false, 'stations.catalogue.review'],
            },
          ],
        }),
        200,
      )),
    );

    final context = await client.getAccessContext();

    expect(context.stationPermissions, {
      'station-valid': {'observation.submit'},
    });
    expect(context.stationRoles, isEmpty);
    expect(context.authorityPermissions, {
      'authority-valid': {'stations.catalogue.review'},
    });
    expect(context.authorityRoles, isEmpty);
    expect(context.hasStationPermission('123', 'observation.create'), isFalse);
    expect(context.hasAuthorityPermission('456', 'authority.access.review'), isFalse);
    client.close();
  });

  test('access context rejects a non-string user identifier', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'invalid-user-token',
      client: MockClient((request) async => http.Response(
        jsonEncode({'userId': 123, 'stations': [], 'authorities': []}),
        200,
      )),
    );

    await expectLater(
      client.getAccessContext(),
      throwsA(isA<FormatException>()),
    );
    client.close();
  });

  const stationId = '11111111-1111-4111-8111-111111111111';
  test('review queue authenticates and parses API rows', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'test-access-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode([
            {
              'id': '22222222-2222-4222-8222-222222222222',
              'station_id': stationId,
              'observation_type': 'daily',
              'observed_at': '2026-11-03T12:00:00Z',
              'status': 'submitted',
              'payload': {'temperature': 28},
            },
          ]),
          200,
        );
      }),
    );
    final rows = await client.getReviewQueue(stationId);
    expect(captured.headers['authorization'], 'Bearer test-access-token');
    expect(rows, hasLength(1));
    expect(rows.single.payload['temperature'], 28);
    client.close();
  });

  test('review queue rejects null and scalar rows without leaking cast errors', () async {
    for (final body in ['[null]', '[42]', '["row"]']) {
      final client = MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'token',
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(client.getReviewQueue(stationId), throwsFormatException);
      client.close();
    }
  });

  test('review queue rejects rows that are not submitted records', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response(
        jsonEncode([
          {
            'id': '22222222-2222-4222-8222-222222222222',
            'station_id': stationId,
            'observation_type': 'daily',
            'observed_at': '2026-11-03T12:00:00Z',
            'payload': {},
          },
        ]),
        200,
      )),
    );
    await expectLater(client.getReviewQueue(stationId), throwsFormatException);
    client.close();
  });

  test('review queue rejects blank identifiers and non-string timestamps', () async {
    final malformedRows = [
      {
        'id': '22222222-2222-4222-8222-222222222222',
        'station_id': '   ',
        'observation_type': 'daily',
        'observed_at': '2026-11-03T12:00:00Z',
        'status': 'submitted',
        'payload': {},
      },
      {
        'id': '22222222-2222-4222-8222-222222222222',
        'station_id': stationId,
        'observation_type': 'daily',
        'observed_at': 1793707200,
        'status': 'submitted',
        'payload': {},
      },
      {
        'id': '   ',
        'station_id': stationId,
        'observation_type': 'daily',
        'observed_at': '2026-11-03T12:00:00Z',
        'status': 'submitted',
        'payload': {},
      },
    ];

    for (final row in malformedRows) {
      final client = MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'token',
        client: MockClient((_) async => http.Response(
          jsonEncode([row]),
          200,
        )),
      );
      await expectLater(client.getReviewQueue(stationId), throwsFormatException);
      client.close();
    }
  });

  test('generic API record lists reject malformed non-object rows', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('[{},null]', 200)),
    );
    await expectLater(
      client.getStationUsers(stationId),
      throwsFormatException,
    );
    client.close();
  });

  test('station directory rejects null and scalar rows as malformed data', () async {
    for (final body in ['[null]', '[42]', '["row"]']) {
      final client = MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'token',
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        client.getStationDirectory(),
        throwsFormatException,
      );
      client.close();
    }
  });

  test('station directory rejects a non-string optional WMO station id', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'directory-token',
      client: MockClient((_) async => http.Response.bytes(
        utf8.encode(jsonEncode([
          {
            'id': stationId,
            'local_station_code': 'ST-001',
            'name_ar': 'محطة اختبار',
            'name_en': 'Test station',
            'station_type': 'classic',
            'operational_status': 'unverified',
            'approval_status': 'pending',
            'wmo_station_id': 123,
          },
        ])),
        200,
      )),
    );
    await expectLater(client.getStationDirectory(), throwsFormatException);
    client.close();
  });

  test('station directory parses coordinate and approval state', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'directory-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {
                'id': stationId,
                'local_station_code': 'ST-001',
                'name_ar': 'محطة اختبار',
                'name_en': 'Test station',
                'station_type': 'classic',
                'operational_status': 'unverified',
                'approval_status': 'pending',
                'is_demo': false,
                'station_coordinates': [
                  {'latitude': 24.7, 'longitude': 46.7},
                ],
              },
            ]),
          ),
          200,
        );
      }),
    );
    final rows = await client.getStationDirectory(stationType: 'classic');
    expect(captured.url.path, '/api/v1/stations');
    expect(captured.url.queryParameters['stationType'], 'classic');
    expect(captured.headers['authorization'], 'Bearer directory-token');
    expect(rows.single.nameArabic, 'محطة اختبار');
    expect(rows.single.hasCoordinates, isTrue);
    expect(rows.single.approvalStatus, 'pending');
    client.close();
  });

  test(
    'station coordinates distinguish missing, valid and out-of-range values',
    () {
      StationDirectoryItem station(double? latitude, double? longitude) =>
          StationDirectoryItem(
            id: stationId,
            localCode: 'ST-001',
            nameArabic: 'اختبار',
            nameEnglish: 'Test',
            stationType: 'classic',
            operationalStatus: 'unverified',
            approvalStatus: 'pending',
            isDemo: false,
            latitude: latitude,
            longitude: longitude,
          );
      expect(station(24.7, 46.7).hasValidCoordinates, isTrue);
      expect(station(null, 46.7).hasValidCoordinates, isFalse);
      expect(station(91, 46.7).hasValidCoordinates, isFalse);
      expect(station(24.7, -181).hasValidCoordinates, isFalse);
    },
  );

  test(
    'station directory fetches every page instead of silently hiding stations',
    () async {
      var requests = 0;
      final client = MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'directory-token',
        client: MockClient((request) async {
          requests++;
          final offset = int.parse(request.url.queryParameters['offset']!);
          final count = offset == 0 ? 500 : 1;
          final rows = List.generate(count, (index) {
            final n = offset + index;
            return {
              'id': 'station-$n',
              'local_station_code': 'ST-$n',
              'name_ar': 'Station $n',
              'name_en': 'Station $n',
              'station_type': 'classic',
              'operational_status': 'unverified',
              'approval_status': 'pending',
              'is_demo': false,
              'station_coordinates': <Map<String, dynamic>>[],
            };
          });
          return http.Response(jsonEncode(rows), 200);
        }),
      );
      final rows = await client.getAllStationDirectory(stationType: 'classic');
      expect(requests, 2);
      expect(rows, hasLength(501));
      expect(rows.last.localCode, 'ST-500');
      client.close();
    },
  );

  test(
    'accepts an exact 10,000-station directory without false overflow',
    () async {
      var requests = 0;
      final client = MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'directory-token',
        client: MockClient((request) async {
          requests++;
          final offset = int.parse(request.url.queryParameters['offset']!);
          final limit = int.parse(request.url.queryParameters['limit']!);
          final count = offset >= 10000
              ? 0
              : (10000 - offset).clamp(0, limit).toInt();
          final rows = List.generate(count, (index) {
            final n = offset + index;
            return {
              'id': 'station-$n',
              'local_station_code': 'ST-$n',
              'name_ar': 'Station $n',
              'name_en': 'Station $n',
              'station_type': 'classic',
              'operational_status': 'unverified',
              'approval_status': 'pending',
              'is_demo': false,
              'station_coordinates': <Map<String, dynamic>>[],
            };
          });
          return http.Response(jsonEncode(rows), 200);
        }),
      );

      final rows = await client.getAllStationDirectory();

      expect(rows, hasLength(10000));
      expect(requests, 21); // 20 full pages plus the one-row overflow probe.
      client.close();
    },
  );

  test(
    'rejects station directories larger than the documented safety cap',
    () async {
      final client = MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'directory-token',
        client: MockClient((request) async {
          final offset = int.parse(request.url.queryParameters['offset']!);
          final limit = int.parse(request.url.queryParameters['limit']!);
          final count = offset >= 10000
              ? 1
              : (10000 - offset).clamp(0, limit).toInt();
          final rows = List.generate(count, (index) {
            final n = offset + index;
            return {
              'id': 'station-$n',
              'local_station_code': 'ST-$n',
              'name_ar': 'Station $n',
              'name_en': 'Station $n',
              'station_type': 'classic',
              'operational_status': 'unverified',
              'approval_status': 'pending',
              'is_demo': false,
              'station_coordinates': <Map<String, dynamic>>[],
            };
          });
          return http.Response(jsonEncode(rows), 200);
        }),
      );

      await expectLater(
        client.getAllStationDirectory(),
        throwsA(
          isA<MetraApiException>().having(
            (error) => error.code,
            'code',
            'station_directory_limit_exceeded',
          ),
        ),
      );
      client.close();
    },
  );

  test(
    'rejects unsupported observation types before making a request',
    () async {
      var requests = 0;
      final client = MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'token',
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        client.submitObservation(
          stationId: stationId,
          idempotencyKey: 'request-1',
          observationType: 'agricultural',
          observedAt: DateTime.utc(2026, 11, 16),
          payload: const {'temperature': 20},
        ),
        throwsA(
          isA<MetraApiException>().having(
            (error) => error.code,
            'code',
            'unsupported_observation_type',
          ),
        ),
      );
      expect(requests, 0);
      client.close();
    },
  );

  test(
    'rejects blank or padded idempotency keys before making a request',
    () async {
      var requests = 0;
      final client = MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'token',
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      for (final key in ['', ' request-1 ', 'request 1']) {
        await expectLater(
          client.submitObservation(
            stationId: stationId,
            idempotencyKey: key,
            observationType: 'hourly',
            observedAt: DateTime.utc(2026, 11, 16),
            payload: const {'dryTemp': 20},
          ),
          throwsA(
            isA<MetraApiException>().having(
              (error) => error.code,
              'code',
              'invalid_idempotency_key',
            ),
          ),
        );
      }
      expect(requests, 0);
      client.close();
    },
  );

  test(
    'rejects blank or padded station IDs before making a request',
    () async {
      var requests = 0;
      final client = MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'token',
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      for (final id in ['', '  ', ' station-a ']) {
        await expectLater(
          client.submitObservation(
            stationId: id,
            idempotencyKey: 'request-1',
            observationType: 'hourly',
            observedAt: DateTime.utc(2026, 11, 16),
            payload: const {'dryTemp': 20},
          ),
          throwsA(isA<MetraApiException>()),
        );
      }
      expect(requests, 0);
      client.close();
    },
  );

  test('submits supported observation with bearer token and UTC timestamp', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'submit-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'id': 'obs-1'}), 200);
      }),
    );
    await client.submitObservation(
      stationId: stationId,
      idempotencyKey: 'idem-1',
      observationType: 'hourly',
      observedAt: DateTime.utc(2026, 11, 16, 8),
      payload: const {'dryTemp': 22.5},
      submit: true,
    );
    expect(captured.method, 'POST');
    expect(captured.headers['authorization'], 'Bearer submit-token');
    expect(captured.headers['idempotency-key'], 'idem-1');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['observationType'], 'hourly');
    expect(body['submit'], isTrue);
    client.close();
  });

  test('rejects malformed station and record identifiers before requests', () async {
    var requests = 0;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      client.getReviewQueue('not-a-uuid'),
      throwsA(isA<MetraApiException>()),
    );
    expect(requests, 0);
    client.close();
  });

  test('maps request and response wait timeouts to safe timeout error', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async {
        throw http.ClientException('Timeout');
      }),
    );
    await expectLater(
      client.getReviewQueue(stationId),
      throwsA(isA<MetraApiException>()),
    );
    client.close();
  });

  test('requires access token', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => null,
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    await expectLater(
      client.getReviewQueue(stationId),
      throwsA(isA<MetraApiException>()),
    );
    client.close();
  });

  test('requires HTTPS API origin', () {
    expect(
      () => MetraApiClient(
        baseUrl: 'http://api.example.test',
        accessTokenProvider: () async => 'token',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('bounds queue limit', () async {
    late http.Request captured;
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('[]', 200);
      }),
    );
    await client.getReviewQueue(stationId, limit: 9999);
    expect(int.parse(captured.url.queryParameters['limit']!), lessThanOrEqualTo(200));
    client.close();
  });

  test('API is not configured when the build-time URL is missing', () {
    expect(ApiConfig.isConfigured, isA<bool>());
  });

  test('rejects API URLs containing credentials, query or fragment', () {
    expect(ApiConfig.isValidUrl('https://user:pass@api.example.test'), isFalse);
    expect(ApiConfig.isValidUrl('https://api.example.test?x=1'), isFalse);
    expect(ApiConfig.isValidUrl('https://api.example.test#frag'), isFalse);
  });

  test('registration roles reject malformed successful responses', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('null', 200)),
    );
    await expectLater(client.getRegistrationRoles(), throwsFormatException);
    client.close();
  });

  test('registration status rejects malformed successful responses', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('"ok"', 200)),
    );
    await expectLater(client.getMyRegistrationStatus(), throwsFormatException);
    client.close();
  });

  test('registration submission never fabricates a submitted result', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    await expectLater(
      client.submitRegistrationRequest(
        stationId: stationId,
        requestedRoleCode: 'observer',
        fullName: 'Test User',
        phone: '0123456789',
      ),
      throwsA(isA<MetraApiException>()),
    );
    client.close();
  });

  test('maps transport exceptions to a safe network-unavailable error', () async {
    final client = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'token',
      client: MockClient((_) async {
        throw http.ClientException('Connection refused');
      }),
    );
    await expectLater(
      client.getReviewQueue(stationId),
      throwsA(
        isA<MetraApiException>().having(
          (e) => e.code,
          'code',
          anyOf('network_unavailable', 'timeout', 'request_failed'),
        ),
      ),
    );
    client.close();
  });
}
