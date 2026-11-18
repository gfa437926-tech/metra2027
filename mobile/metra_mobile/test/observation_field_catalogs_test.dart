import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/catalog/observation_field_catalogs.dart';
import 'package:metra_mobile/core/widgets/metra_observation_form.dart';

void main() {
  test('hourly catalog uses only approved field ids and proven temp bounds', () {
    final ids = ObservationFieldCatalogs.hourly.map((f) => f.id).toSet();
    expect(ids.contains('dryTemp'), isTrue);
    expect(ids.contains('wetTemp'), isTrue);
    expect(ids.contains('inventedField'), isFalse);

    final dry =
        ObservationFieldCatalogs.hourly.firstWhere((f) => f.id == 'dryTemp');
    expect(dry.minimum, -20);
    expect(dry.maximum, 50);
    expect(dry.required, isTrue);
    expect(dry.kind, MetraFieldKind.decimal);
  });

  test('daily catalog enforces proven precipitation bounds', () {
    final precip = ObservationFieldCatalogs.daily
        .firstWhere((f) => f.id == 'precipitation');
    expect(precip.minimum, 0);
    expect(precip.maximum, 999.9);
    expect(precip.required, isTrue);
  });

  test('catalogs do not invent humidity bounds outside proven sources', () {
    final hourlyRh = ObservationFieldCatalogs.hourly
        .firstWhere((f) => f.id == 'relativeHumidity');
    expect(hourlyRh.minimum, 1);
    expect(hourlyRh.maximum, 100);
  });

  test('seven local catalogues keep stable counts and unique field ids', () {
    final catalogs = <String, List<MetraObservationField>>{
      'agricultural': ObservationFieldCatalogs.agricultural,
      'hourlyclimate': ObservationFieldCatalogs.hourlyclimate,
      'rainfall': ObservationFieldCatalogs.rainfall,
      'soil': ObservationFieldCatalogs.soil,
      'faultequipment': ObservationFieldCatalogs.faultequipment,
      'faulttelecom': ObservationFieldCatalogs.faulttelecom,
      'faultit': ObservationFieldCatalogs.faultit,
    };

    expect(catalogs['agricultural']!.length, 31);
    expect(catalogs['hourlyclimate']!.length, 15);
    expect(catalogs['rainfall']!.length, 7);
    expect(catalogs['soil']!.length, 7);
    expect(catalogs['faultequipment']!.length, 15);
    expect(catalogs['faulttelecom']!.length, 21);
    expect(catalogs['faultit']!.length, 10);

    for (final entry in catalogs.entries) {
      final ids = entry.value.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length, reason: entry.key);
      for (final field in entry.value) {
        expect(field.catalogId, isNotNull, reason: '${entry.key}.${field.id}');
        expect(field.label.trim(), isNotEmpty);
        if (field.kind == MetraFieldKind.choice && field.required) {
          expect(
            field.choices,
            isNotEmpty,
            reason: 'required choice ${entry.key}.${field.id} needs options',
          );
        }
      }
    }
  });

  test('rainfall and soil require observation date and agreement', () {
    bool req(List<MetraObservationField> fields, String id) =>
        fields.firstWhere((f) => f.id == id).required;

    expect(req(ObservationFieldCatalogs.rainfall, 'observationDate'), isTrue);
    expect(
      req(ObservationFieldCatalogs.rainfall, 'responsibilityAgreement'),
      isTrue,
    );
    expect(req(ObservationFieldCatalogs.soil, 'observationDate'), isTrue);
    expect(
      req(ObservationFieldCatalogs.soil, 'responsibilityAgreement'),
      isTrue,
    );
  });

  test('hourlyclimate remains distinct from operational hourly catalog', () {
    final climateIds =
        ObservationFieldCatalogs.hourlyclimate.map((f) => f.id).toSet();
    final hourlyIds = ObservationFieldCatalogs.hourly.map((f) => f.id).toSet();
    // Shared meteorological names may overlap; catalogues must stay separate lists.
    expect(identical(ObservationFieldCatalogs.hourlyclimate,
        ObservationFieldCatalogs.hourly), isFalse);
    expect(climateIds.contains('stationPressure'), isTrue);
    expect(hourlyIds.contains('dryTemp'), isTrue);
  });
}
