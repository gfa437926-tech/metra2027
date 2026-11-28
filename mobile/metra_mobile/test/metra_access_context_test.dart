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
      expect(context.hasKnownActiveAccount, isFalse);
    });

    test('hides operational destinations while unresolved', () {
      expect(
        context.isDestinationVisible(MetraDestinationId.observations),
        isFalse,
      );
      expect(context.isDestinationVisible(MetraDestinationId.admin), isFalse);
      expect(context.isDestinationVisible(MetraDestinationId.home), isTrue);
      expect(context.isDestinationVisible(MetraDestinationId.stations), isTrue);
      expect(context.isDestinationVisible(MetraDestinationId.settings), isTrue);
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

  group('MetraAccessContext.resolved permission fixtures', () {
    final observer = MetraAccessContext.resolved(
      userId: 'user-observer',
      accountState: 'active',
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
      accountState: 'active',
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
      accountState: 'active',
      stationPermissions: {
        'station-a': {'observation.create', 'observation.submit'},
        'station-b': {'observation.review', 'users.station.view'},
      },
    );

    test('observer may enter observations only on assigned station', () {
      expect(observer.isResolved, isTrue);
      expect(observer.hasKnownActiveAccount, isTrue);
      expect(observer.canEnterObservations('station-a'), isTrue);
      expect(observer.canReviewObservations('station-a'), isFalse);
      expect(observer.canAdministerStation('station-a'), isFalse);
      expect(observer.canEnterObservations('station-b'), isFalse);
      expect(observer.canAccessAnyObservationWorkspace, isTrue);
      expect(observer.canAccessAnyStationAdministration, isFalse);
      expect(
        observer.isDestinationVisible(MetraDestinationId.observations),
        isTrue,
      );
      expect(observer.isDestinationVisible(MetraDestinationId.admin), isFalse);
    });

    test('station_head may review and administer on assigned station', () {
      expect(stationHead.canEnterObservations('station-a'), isFalse);
      expect(stationHead.canReviewObservations('station-a'), isTrue);
      expect(stationHead.canAdministerStation('station-a'), isTrue);
      expect(stationHead.canAccessAnyStationAdministration, isTrue);
      expect(
        stationHead.isDestinationVisible(MetraDestinationId.admin),
        isTrue,
      );
      expect(
        stationHead.isDestinationVisible(MetraDestinationId.observations),
        isTrue,
      );
    });

    test('permissions differ across stations', () {
      expect(multi.canEnterObservations('station-a'), isTrue);
      expect(multi.canEnterObservations('station-b'), isFalse);
      expect(multi.canReviewObservations('station-b'), isTrue);
      expect(multi.canAdministerStation('station-b'), isTrue);
      expect(multi.canAdministerStation('station-a'), isFalse);
    });

    test('edit_own_draft alone allows observation workspace entry', () {
      final draftOnly = MetraAccessContext.resolved(
        userId: 'draft',
        accountState: 'active',
        stationPermissions: {
          'station-a': {'observation.edit_own_draft'},
        },
      );
      expect(draftOnly.canEnterObservations('station-a'), isTrue);
      expect(draftOnly.canAccessObservationWorkspace('station-a'), isTrue);
      expect(
        draftOnly.isDestinationVisible(MetraDestinationId.observations),
        isTrue,
      );
    });

    test('resolved context rejects a blank user identity', () {
      expect(
        () => MetraAccessContext.resolved(
          userId: '  ',
          stationPermissions: {
            'station-a': {'observation.create'},
          },
        ),
        throwsArgumentError,
      );
    });

    test('empty identifiers never grant access', () {
      expect(observer.hasStationPermission('', 'observation.create'), isFalse);
      expect(observer.hasStationPermission('station-a', ''), isFalse);
    });

    test('authority permissions remain isolated from station permissions', () {
      final context = MetraAccessContext.resolved(
        userId: 'director',
        accountState: 'active',
        stationPermissions: {'station-a': {'observation.create'}},
        authorityPermissions: {'authority-a': {'stations.catalogue.review'}},
        authorityRoles: {'authority-a': 'network_director'},
      );
      expect(context.hasAuthorityPermission('authority-a', 'stations.catalogue.review'), isTrue);
      expect(context.hasAuthorityPermission('station-a', 'stations.catalogue.review'), isFalse);
      expect(context.hasStationPermission('authority-a', 'stations.catalogue.review'), isFalse);
      expect(context.authorityRoles['authority-a'], 'network_director');
    });

    test('unresolved context denies authority permissions', () {
      expect(MetraAccessContext.unresolved().hasAuthorityPermission('authority-a', 'stations.catalogue.review'), isFalse);
    });
  });

  group('accountState gates operational access', () {
    test('unknown accountState does not grant operational permissions', () {
      final unknown = MetraAccessContext.resolved(
        userId: 'user-unknown',
        accountState: 'unknown',
        stationPermissions: {
          'station-a': {
            'observation.create',
            'observation.submit',
            'observation.review',
            'users.station.manage',
          },
        },
      );
      expect(unknown.isResolved, isTrue);
      expect(unknown.hasKnownActiveAccount, isFalse);
      expect(unknown.canEnterObservations('station-a'), isFalse);
      expect(unknown.canReviewObservations('station-a'), isFalse);
      expect(unknown.canAdministerStation('station-a'), isFalse);
      expect(unknown.canAccessAnyObservationWorkspace, isFalse);
      expect(unknown.canAccessAnyStationAdministration, isFalse);
      expect(
        unknown.isDestinationVisible(MetraDestinationId.observations),
        isFalse,
      );
      expect(unknown.isDestinationVisible(MetraDestinationId.admin), isFalse);
    });

    test('inactive account does not grant operational permissions', () {
      final inactive = MetraAccessContext.resolved(
        userId: 'user-inactive',
        accountState: 'inactive',
        stationPermissions: {
          'station-a': {'observation.create', 'observation.submit'},
        },
      );
      expect(inactive.isResolved, isTrue);
      expect(inactive.hasKnownActiveAccount, isFalse);
      expect(inactive.canEnterObservations('station-a'), isFalse);
      expect(inactive.canAccessAnyObservationWorkspace, isFalse);
    });

    test('null accountState does not grant operational permissions', () {
      final noState = MetraAccessContext.resolved(
        userId: 'user-null-state',
        accountState: null,
        stationPermissions: {
          'station-a': {'observation.create'},
        },
      );
      expect(noState.hasKnownActiveAccount, isFalse);
      expect(noState.canEnterObservations('station-a'), isFalse);
    });

    test('active account reports known-active and grants codes', () {
      final active = MetraAccessContext.resolved(
        userId: 'user-active',
        accountState: 'active',
        stationPermissions: {
          'station-a': {'observation.create'},
        },
      );
      expect(active.hasKnownActiveAccount, isTrue);
      expect(active.canEnterObservations('station-a'), isTrue);
    });
  });

  group('placeholder destinations', () {
    test('placeholder destinations remain visible while unresolved', () {
      final context = MetraAccessContext.unresolved();
      expect(context.isDestinationVisible(MetraDestinationId.forecast), isTrue);
      expect(context.isDestinationVisible(MetraDestinationId.climatol), isTrue);
      expect(
        context.isDestinationVisible(MetraDestinationId.recordsAi),
        isTrue,
      );
      expect(
        context.isDestinationVisible(MetraDestinationId.operations),
        isTrue,
      );
      expect(context.isDestinationVisible(MetraDestinationId.reports), isTrue);
      expect(
        context.isDestinationVisible(MetraDestinationId.observations),
        isFalse,
      );
      expect(context.isDestinationVisible(MetraDestinationId.admin), isFalse);
    });
  });
}
