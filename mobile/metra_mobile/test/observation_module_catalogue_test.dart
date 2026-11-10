import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/observations/observation_module_catalogue.dart';

void main() {
  test('catalogue contains every requested operational module', () {
    expect(observationModuleCatalogue.map((e) => e.module).toSet(), {
      ObservationModule.hourly,
      ObservationModule.daily,
      ObservationModule.agricultural,
      ObservationModule.rainfall,
      ObservationModule.weatherPhenomenon,
      ObservationModule.agriculturalPhenomenon,
      ObservationModule.soilTemperature,
      ObservationModule.observationEquipmentFault,
      ObservationModule.telecommunicationsFault,
      ObservationModule.itIncident,
    });
  });

  test('notes and acknowledgement are separate from meteorological payload fields', () {
    for (final module in observationModuleCatalogue) {
      final dataKeys = module.fields.map((field) => field.key).toSet();
      final metadataKeys = module.metadataFields.map((field) => field.key).toSet();
      expect(dataKeys.intersection(metadataKeys), isEmpty,
          reason: module.title);
      expect(dataKeys.contains('observerNotes'), isFalse, reason: module.title);
      expect(dataKeys.contains('responsibilityAgreement'), isFalse,
          reason: module.title);
    }
  });

  test('only API-supported observation types are marked submit-capable', () {
    final supported = observationModuleCatalogue
        .where((module) => module.submitSupportedByCurrentApi)
        .map((module) => module.module)
        .toSet();
    expect(supported, {
      ObservationModule.hourly,
      ObservationModule.daily,
      ObservationModule.weatherPhenomenon,
    });
    for (final module in observationModuleCatalogue.where(
        (module) => !module.submitSupportedByCurrentApi)) {
      expect(module.apiObservationType, isNull, reason: module.title);
    }
  });

  test('source-specific conditional rules are recorded without guessing', () {
    final hourly = observationModuleSpec(ObservationModule.hourly);
    expect(hourly.sourceNotes.any((note) => note.contains('00 و06 و12 و18')), isTrue);
    expect(hourly.sourceNotes.any((note) => note.contains('03 و09')), isTrue);

    final daily = observationModuleSpec(ObservationModule.daily);
    expect(daily.sourceNotes.any((note) => note.contains('snowThickness')), isTrue);

    final soil = observationModuleSpec(ObservationModule.soilTemperature);
    expect(soil.sourceNotes.any((note) => note.contains('23,02,05,08')), isTrue);
  });

  test('original field identifiers are retained for representative modules', () {
    expect(
      observationModuleSpec(ObservationModule.agricultural)
          .fields.map((field) => field.key),
      containsAll(['avgAirTemp', 'avgSoilTemp50cm', 'classAEvaporation']),
    );
    expect(
      observationModuleSpec(ObservationModule.rainfall)
          .fields.map((field) => field.key),
      containsAll(['utcTime', 'rainAmount', 'snowDepth']),
    );
    expect(
      observationModuleSpec(ObservationModule.telecommunicationsFault)
          .fields.map((field) => field.key),
      containsAll(['phoneType', 'towerType', 'satelliteType', 'wifiType']),
    );
    expect(
      observationModuleSpec(ObservationModule.itIncident)
          .fields.map((field) => field.key),
      containsAll(['bulletinType', 'problemField', 'problemUrgency']),
    );
  });
}
