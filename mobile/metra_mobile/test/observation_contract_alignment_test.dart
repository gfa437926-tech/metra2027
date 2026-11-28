import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/catalog/observation_field_catalogs.dart';
import 'package:metra_mobile/core/catalog/phenomenon_field_catalog.dart';
import 'package:metra_mobile/core/catalog_integration/catalog_form_type.dart';
import 'package:metra_mobile/core/catalog_integration/local_catalog_observation_repository.dart';

/// Cross-checks Flutter catalogues against the approved .NET domain contracts
/// without inventing new endpoints or payload shapes.
void main() {
  group('server-backed observation field contracts', () {
    test('phenomenon catalogue exposes WeatherPhenomenonValidator fields', () {
      final ids = PhenomenonFieldCatalog.fields.map((f) => f.id).toSet();
      expect(
        ids,
        containsAll({
          'phenomenonType',
          'phenomenonDate',
          'startTime',
          'endTime',
          'generalNotes',
          'responsibilityAgreement',
        }),
      );
      final required = PhenomenonFieldCatalog.fields
          .where((f) => f.required)
          .map((f) => f.id)
          .toSet();
      expect(
        required,
        containsAll({
          'phenomenonType',
          'phenomenonDate',
          'startTime',
          'responsibilityAgreement',
        }),
      );
      expect(required.contains('endTime'), isFalse);
    });

    test(
      'hourly catalogue covers ObservationSubmissionDomainValidator required',
      () {
        const serverRequired = {
          'utcTime',
          'dryTemp',
          'wetTemp',
          'stationPressure',
          'seaLevelPressure',
          'relativeHumidity',
          'dewPoint',
          'windDirection',
          'windSpeed',
          'visibility',
          'totalCloudCover',
          'cover12',
          'cover123',
          'responsibilityAgreement',
        };
        final clientIds = ObservationFieldCatalogs.hourly
            .map((f) => f.id)
            .toSet();
        expect(clientIds, containsAll(serverRequired));
      },
    );

    test(
      'daily catalogue covers ObservationSubmissionDomainValidator required',
      () {
        const serverRequired = {
          'currentDate',
          'minTemp',
          'maxTemp',
          'precipitation',
          'snowThickness',
          'evaporation',
          'sunshineDuration',
          'sunshinePercentage',
          'maxGustSpeed',
          'maxGustDirection',
          'maxGustTime',
          'maxHumidity',
          'maxHumidityTime',
          'minHumidity',
          'minHumidityTime',
          'responsibilityAgreement',
        };
        final clientIds = ObservationFieldCatalogs.daily
            .map((f) => f.id)
            .toSet();
        expect(clientIds, containsAll(serverRequired));
      },
    );
  });

  group('local-only catalogue forms remain non-server', () {
    test(
      'seven catalogue codes stay distinct from server observation types',
      () {
        const serverTypes = {'hourly', 'daily', 'phenomenon'};
        for (final type in CatalogFormType.values) {
          expect(serverTypes.contains(type.code), isFalse, reason: type.code);
          expect(type.pendingContractNotice, contains('عقد API'));
        }
      },
    );

    test(
      'local repository never claims server persistence for any type',
      () async {
        final repo = LocalCatalogObservationRepository();
        for (final type in CatalogFormType.values) {
          final result = await repo.submitLocal(
            type: type,
            stationId: 'station-x',
            values: const {},
          );
          expect(result.claimsServerPersistence, isFalse, reason: type.code);
        }
      },
    );
  });
}
