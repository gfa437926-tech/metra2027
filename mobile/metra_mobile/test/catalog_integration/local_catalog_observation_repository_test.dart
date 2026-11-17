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
}
