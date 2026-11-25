import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/catalog_integration/catalog_form_type.dart';
import 'package:metra_mobile/core/catalog_integration/catalog_submission_state.dart';
import 'package:metra_mobile/core/catalog_integration/local_catalog_observation_repository.dart';
import 'package:metra_mobile/core/drafts/observation_draft_store.dart';
import 'package:metra_mobile/core/widgets/metra_observation_form.dart';

void main() {
  late ObservationDraftStore drafts;
  late LocalCatalogObservationRepository repo;

  setUp(() {
    drafts = ObservationDraftStore.instance;
    drafts.clearAll();
    repo = LocalCatalogObservationRepository(draftStore: drafts);
  });

  tearDown(() => drafts.clearAll());

  test('rainfall required fields block local accept', () async {
    final result = await repo.submitLocal(
      type: CatalogFormType.rainfall,
      stationId: 'station-a',
      values: const {},
    );

    expect(result.phase, CatalogSubmissionPhase.failed);
    expect(result.claimsServerPersistence, isFalse);
    expect(result.validationErrors, isNotEmpty);
  });

  test('valid rainfall values await API contract and keep station-scoped draft',
      () async {
    final fields = repo.fieldsFor(CatalogFormType.rainfall);
    final values = <String, Object?>{};
    for (final field in fields) {
      if (field.kind == MetraFieldKind.boolean) {
        values[field.id] = true;
      } else if (field.required) {
        values[field.id] = '2026-11-17';
      } else {
        values[field.id] = '1';
      }
    }

    final result = await repo.submitLocal(
      type: CatalogFormType.rainfall,
      stationId: 'station-a',
      values: values,
    );

    expect(result.phase, CatalogSubmissionPhase.awaitingApiContract);
    expect(result.claimsServerPersistence, isFalse);
    expect(result.messageAr, contains('عقد API'));
    expect(drafts.get('station-a', 'rainfall'), isNotNull);
    expect(drafts.get('station-b', 'rainfall'), isNull);
  });

  test('empty station id is rejected', () async {
    final result = await repo.submitLocal(
      type: CatalogFormType.soil,
      stationId: '  ',
      values: const {},
    );
    expect(result.phase, CatalogSubmissionPhase.failed);
    expect(result.messageAr, contains('المحطة'));
  });

  test('all seven catalogue types expose non-empty field lists', () {
    for (final type in CatalogFormType.values) {
      expect(repo.fieldsFor(type), isNotEmpty, reason: type.code);
    }
  });

  test('rainfall rejects non-numeric rainAmount after decimal kind', () async {
    final result = await repo.submitLocal(
      type: CatalogFormType.rainfall,
      stationId: 'station-a',
      values: {
        'observationDate': '2026-11-17',
        'responsibilityAgreement': true,
        'rainAmount': 'abc',
      },
    );
    expect(result.phase, CatalogSubmissionPhase.failed);
    expect(result.validationErrors.containsKey('rainAmount'), isTrue);
    expect(result.claimsServerPersistence, isFalse);
  });

  test('soil accepts finite depth decimals and awaits API contract', () async {
    final result = await repo.submitLocal(
      type: CatalogFormType.soil,
      stationId: 'station-a',
      values: {
        'observationDate': '2026-11-17',
        'responsibilityAgreement': true,
        'depth5': '18.5',
        'depth10': '17',
      },
    );
    expect(result.phase, CatalogSubmissionPhase.awaitingApiContract);
    expect(result.claimsServerPersistence, isFalse);
    expect(drafts.get('station-a', 'soil'), isNotNull);
  });

  test('agricultural empty values fail required fields', () async {
    final result = await repo.submitLocal(
      type: CatalogFormType.agricultural,
      stationId: 'station-a',
      values: const {},
    );
    expect(result.phase, CatalogSubmissionPhase.failed);
    expect(result.claimsServerPersistence, isFalse);
    expect(result.validationErrors, isNotEmpty);
  });

  test('fault equipment rejects unknown choice values', () async {
    final fields = repo.fieldsFor(CatalogFormType.faultEquipment);
    final values = <String, Object?>{};
    for (final field in fields) {
      if (field.kind == MetraFieldKind.boolean) {
        values[field.id] = true;
      } else if (field.kind == MetraFieldKind.choice && field.choices.isNotEmpty) {
        values[field.id] = '__invalid_choice__';
      } else if (field.required) {
        values[field.id] = 'x';
      }
    }
    final result = await repo.submitLocal(
      type: CatalogFormType.faultEquipment,
      stationId: 'station-a',
      values: values,
    );
    expect(result.phase, CatalogSubmissionPhase.failed);
    expect(result.claimsServerPersistence, isFalse);
  });

  test('fault telecom accepts filled required fields and awaits contract', () async {
    final fields = repo.fieldsFor(CatalogFormType.faultTelecom);
    final values = <String, Object?>{};
    for (final field in fields) {
      if (field.kind == MetraFieldKind.boolean) {
        values[field.id] = true;
      } else if (field.kind == MetraFieldKind.choice && field.choices.isNotEmpty) {
        values[field.id] = field.choices.first;
      } else if (field.required) {
        values[field.id] = field.kind == MetraFieldKind.integer ? '1' : 'note';
      }
    }
    final result = await repo.submitLocal(
      type: CatalogFormType.faultTelecom,
      stationId: 'station-a',
      values: values,
    );
    expect(result.phase, CatalogSubmissionPhase.awaitingApiContract);
    expect(result.claimsServerPersistence, isFalse);
    expect(drafts.get('station-a', CatalogFormType.faultTelecom.code), isNotNull);
  });
}
