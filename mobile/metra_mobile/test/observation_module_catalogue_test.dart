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

  test('06 and 18 UTC synoptic reports belong to hourly and daily is 24h only', () {
    final hourlyReports = observationModuleSpecs(ObservationModule.hourly);
    final variants = hourlyReports.map((item) => item.reportVariant).toSet();
    expect(variants, containsAll({
      ObservationReportVariant.standardHourly,
      ObservationReportVariant.synoptic06Utc,
      ObservationReportVariant.synoptic18Utc,
    }));

    final daily = observationModuleSpec(ObservationModule.daily);
    expect(daily.reportVariant, ObservationReportVariant.daily24Hours);
    expect(daily.fields.any((field) => field.key == 'reportType'), isFalse);

    for (final variant in [
      ObservationReportVariant.synoptic06Utc,
      ObservationReportVariant.synoptic18Utc,
    ]) {
      final report = hourlyReports.singleWhere((item) => item.reportVariant == variant);
      expect(report.module, ObservationModule.hourly);
      expect(report.fields.map((field) => field.key), containsAll([
        'minTemp', 'maxTemp', 'precipitation', 'snowThickness',
      ]));
      expect(report.submitSupportedByCurrentApi, isFalse);
      expect(report.apiObservationType, isNull);
      expect(report.sourceNotes.any((note) => note.contains('لا يعرض أو يحسب أي توقيت محلي')), isTrue);
    }
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
      observationModuleSpec(ObservationModule.rainfall)
          .fields.map((field) => field.key),
      isNot(contains('localTime')),
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
