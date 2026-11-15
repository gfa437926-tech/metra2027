/// Wire states defined by the METRA recorder digitization job contract.
/// Unknown values are not coerced to a valid state.
enum RecordDigitizationJobStatus {
  queued,
  validating,
  running,
  succeeded,
  failed,
  cancelled;

  static RecordDigitizationJobStatus? tryParse(Object? value) {
    if (value is! String) return null;
    for (final status in values) {
      if (status.name == value) return status;
    }
    return null;
  }

  bool get isTerminal => switch (this) {
        succeeded || failed || cancelled => true,
        _ => false,
      };

  bool canTransitionTo(RecordDigitizationJobStatus next) {
    if (this == next || isTerminal) return false;
    return switch (this) {
      queued => next == validating || next == cancelled,
      validating =>
        next == running || next == failed || next == cancelled,
      running =>
        next == succeeded || next == failed || next == cancelled,
      succeeded || failed || cancelled => false,
    };
  }
}
