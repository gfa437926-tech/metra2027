import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/auth/metra_access_context.dart';

void main() {
  group('MetraAccessContext.unresolved (fail-closed)', () {
    final context = MetraAccessContext.unresolved();

    test('is not resolved and has no user or stations', () {
      expect(context.isResolved, isFalse);
      expect(context.userId, isNull);
      expect(context.stationPermissions, isEmpty);
    });

    test('denies every station permission while unresolved', () {
      expect(
        context.hasStationPermission('station-a', 'observation.create'),
        isFalse,
      );
      expect(
        context.hasStationPermission('station-a', 'observation.review'),
        isFalse,
      );
      expect(
        context.hasStationPermission('station-a', 'users.station.view'),
        isFalse,
      );
      expect(context.canEnterObservations('station-a'), isFalse);
      expect(context.canReviewObservations('station-a'), isFalse);
      expect(context.canAdministerStation('station-a'), isFalse);
    });
  });

  group('MetraAccessContext.resolved (server-shaped fixture only)', () {
    final observer = MetraAccessContext.resolved(
      userId: 'user-observer',
      stationPermissions: {
        'station-a': {
          'observation.create',
          'observation.edit_own_draft',
          'observation.submit',
        },
      },
    );

    final stationHead = MetraAccessContext.resolved(
      userId: 'user-head',
      stationPermissions: {
        'station-a': {
          'observation.review',
          'observation.return_for_correction',
          'registrations.station.approve',
          'users.station.view',
          'users.station.manage',
        },
      },
    );

    final auditor = MetraAccessContext.resolved(
      userId: 'user-auditor',
      stationPermissions: {
        'station-a': {
          'observation.review',
          'observation.return_for_correction',
        },
      },
    );

    test('observer may enter observations only on assigned station', () {
      expect(observer.isResolved, isTrue);
      expect(observer.canEnterObservations('station-a'), isTrue);
      expect(observer.canReviewObservations('station-a'), isFalse);
      expect(observer.canAdministerStation('station-a'), isFalse);
      expect(observer.canEnterObservations('station-b'), isFalse);
    });

    test('station_head may review and administer on assigned station', () {
      expect(stationHead.canEnterObservations('station-a'), isFalse);
      expect(stationHead.canReviewObservations('station-a'), isTrue);
      expect(stationHead.canAdministerStation('station-a'), isTrue);
      expect(stationHead.canAdministerStation('station-b'), isFalse);
    });

    test('station_auditor may review but not administer', () {
      expect(auditor.canReviewObservations('station-a'), isTrue);
      expect(auditor.canAdministerStation('station-a'), isFalse);
      expect(auditor.canEnterObservations('station-a'), isFalse);
    });

    test('empty or blank identifiers never grant access', () {
      expect(observer.hasStationPermission('', 'observation.create'), isFalse);
      expect(observer.hasStationPermission('station-a', ''), isFalse);
      expect(observer.hasStationPermission('  ', 'observation.create'), isFalse);
    });

    test('does not grant permissions not present in the fixture', () {
      expect(
        observer.hasStationPermission('station-a', 'observation.approve'),
        isFalse,
      );
      expect(
        observer.hasStationPermission('station-a', 'users.station.manage'),
        isFalse,
      );
    });
  });
}
