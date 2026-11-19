import '../widgets/metra_observation_form.dart';
import 'catalog_form_type.dart';
import 'catalog_submission_state.dart';

/// Abstraction between catalogue UIs and future data sources.
///
/// Implementations must never invent HTTP endpoints. The default local
/// implementation validates only and returns [CatalogSubmissionPhase.awaitingApiContract].
abstract class CatalogObservationRepository {
  /// Field definitions approved for [type] (PR #53 catalogues).
  List<MetraObservationField> fieldsFor(CatalogFormType type);

  /// Validates [values] against the catalogue without network I/O.
  ///
  /// Returns localAccepted / awaitingApiContract on success, or failed with
  /// field-level messages. Never claims a server write.
  Future<CatalogSubmissionResult> submitLocal({
    required CatalogFormType type,
    required String stationId,
    required Map<String, Object?> values,
  });
}
