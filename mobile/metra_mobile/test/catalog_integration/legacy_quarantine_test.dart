import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/catalog_integration/local_catalog_record.dart';

void main() {
  late LocalCatalogRecord legacy;
  late LocalCatalogRecord userA;
  late LocalCatalogRecord userB;

  setUp(() {
    legacy = LocalCatalogRecord(
      id: 'legacy-1',
      stationId: 'st-a',
      formType: 'rainfall',
      values: const {'observationDate': '2019-01-01'},
      createdAt: DateTime.utc(2019, 1, 1),
      updatedAt: DateTime.utc(2019, 1, 1),
    );
    userA = LocalCatalogRecord(
      id: 'a-1',
      stationId: 'st-a',
      formType: 'rainfall',
      values: const {'observationDate': '2020-01-01'},
      createdAt: DateTime.utc(2020, 1, 1),
      updatedAt: DateTime.utc(2020, 1, 1),
      accountKey: 'user-a',
    );
    userB = LocalCatalogRecord(
      id: 'b-1',
      stationId: 'st-a',
      formType: 'rainfall',
      values: const {'observationDate': '2021-01-01'},
      createdAt: DateTime.utc(2021, 1, 1),
      updatedAt: DateTime.utc(2021, 1, 1),
      accountKey: 'user-b',
    );
  });

  test('signed-in account does not see unassigned legacy rows', () {
    final forA = LocalCatalogRecordQuery.filter(
      records: [legacy, userA, userB],
      accountKey: 'user-a',
    );
    expect(forA.map((e) => e.id), ['a-1']);
  });

  test('account B never sees account A rows', () {
    final forB = LocalCatalogRecordQuery.filter(
      records: [legacy, userA, userB],
      accountKey: 'user-b',
    );
    expect(forB.map((e) => e.id), ['b-1']);
  });

  test('unassigned quarantine lists only null-account records', () {
    final q = LocalCatalogRecordQuery.unassigned(
      records: [legacy, userA, userB],
    );
    expect(q.single.id, 'legacy-1');
  });

  test('claim preserves id and content', () {
    final claimed = LocalCatalogRecord(
      id: legacy.id,
      stationId: legacy.stationId,
      formType: legacy.formType,
      values: legacy.values,
      createdAt: legacy.createdAt,
      updatedAt: DateTime.utc(2022, 1, 1),
      status: legacy.status,
      schemaVersion: legacy.schemaVersion,
      accountKey: 'user-a',
    );
    expect(claimed.id, 'legacy-1');
    expect(claimed.values['observationDate'], '2019-01-01');
    expect(claimed.accountKey, 'user-a');
  });
}
