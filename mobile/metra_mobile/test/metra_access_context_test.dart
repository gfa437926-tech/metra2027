import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/auth/metra_access_context.dart';

void main() {
  group('MetraAccessContext.unresolved (fail-closed)', () {
    final context = MetraAccessContext.unresolved();

    test('is not resolved and has no user or stations', () {
      expect(context.isResolved, isFalse);
      expect(context.userId, isNull);
      expect(context.stationPermissions, isEmpty);
      expect(context.canAccessAnyObservationWorkspace, isFalse);
      expect(context.canAccessAnyStationAdministration, isFalse);
    });

    test('denies every station permission while unresolved', () {
      expect(
        context.hasStationPermission('station-a', 'observation.create'),
        isFalse,
      );
      expect(context.canEnterObservations('station-a'), isFalse);
      expect(context.canReviewObservations('station-a'), isFalse);
      expect(context.canAdministerStation('station-a'), isFalse);
    });
  });

  group('MetraAccessContext.resolved role fixtures', () {
    final observer = MetraAccessContext.resolved(
      userId: 'user-observer',
      accountState: 'unknown',
      stationPermissions: {
        'station-a': {
          'observation.create',
          'observation.edit_own_draft',
          'observation.submit',
        },
      },
      stationRoles: {'station-a': 'observer'},
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
      stationRoles: {'station-a': 'station_head'},
    );

    final multi = MetraAccessContext.resolved(
      userId: 'user-multi',
      stationPermissions: {
        'station-a': {'observation.create', 'observation.submit'},
        'station-b': {'observation.review', 'users.station.view'},
      },
    );

    test('observer may enter observations only on assigned station', () {
      expect(observer.isResolved, isTrue);
      expect(observer.canEnterObservations('station-a'), isTrue);
      expect(observer.canReviewObservations('station-a'), isFalse);
      expect(observer.canAdministerStation('station-a'), isFalse);
      expect(observer.canEnterObservations('station-b'), isFalse);
      expect(observer.canAccessAnyObservationWorkspace, isTrue);
      expect(observer.canAccessAnyStationAdministration, isFalse);
    });

    test('station_head may review and administer on assigned station', () {
      expect(stationHead.canEnterObservations('station-a'), isFalse);
      expect(stationHead.canReviewObservations('station-a'), isTrue);
      expect(stationHead.canAdministerStation('station-a'), isTrue);
      expect(stationHead.canAccessAnyStationAdministration, isTrue);
    });

    test('permissions differ across stations', () {
      expect(multi.canEnterObservations('station-a'), isTrue);
      expect(multi.canEnterObservations('station-b'), isFalse);
      expect(multi.canReviewObservations('station-b'), isTrue);
      expect(multi.canAdministerStation('station-b'), isTrue);
      expect(multi.canAdministerStation('station-a'), isFalse);
    });

    test('empty identifiers never grant access', () {
      expect(observer.hasStationPermission('', 'observation.create'), isFalse);
      expect(observer.hasStationPermission('station-a', ''), isFalse);
    });
  });
}
