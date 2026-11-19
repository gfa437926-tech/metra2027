/// Lifecycle for a local catalogue form submission attempt.
enum CatalogSubmissionPhase {
  idle,
  validating,
  /// Values accepted locally; no server write occurred.
  localAccepted,
  /// Explicitly blocked because no approved API contract exists.
  awaitingApiContract,
  failed,
}

/// Immutable result of a catalogue form submit attempt.
class CatalogSubmissionResult {
  const CatalogSubmissionResult({
    required this.phase,
    required this.messageAr,
    this.values = const {},
    this.validationErrors = const {},
  });

  final CatalogSubmissionPhase phase;
  final String messageAr;
  final Map<String, Object?> values;
  final Map<String, String> validationErrors;

  bool get isSuccess =>
      phase == CatalogSubmissionPhase.localAccepted ||
      phase == CatalogSubmissionPhase.awaitingApiContract;

  bool get claimsServerPersistence => false;
}
