/// Wire states for the secure recorder-image intake lifecycle.
/// Quarantined and scanning assets are not considered available evidence.
enum RecordImageAssetStatus {
  awaitingUpload,
  uploadedQuarantined,
  scanning,
  accepted,
  rejected,
  expired,
  cancelled;

  static RecordImageAssetStatus? tryParse(Object? value) {
    if (value is! String) return null;
    for (final status in values) {
      if (status.name == value) return status;
    }
    return null;
  }

  bool get isTerminal => switch (this) {
        accepted || rejected || expired || cancelled => true,
        _ => false,
      };

  bool get isAvailableEvidence => this == accepted;

  bool canTransitionTo(RecordImageAssetStatus next) {
    if (this == next || isTerminal) return false;
    return switch (this) {
      awaitingUpload =>
        next == uploadedQuarantined || next == expired || next == cancelled,
      uploadedQuarantined =>
        next == scanning || next == expired || next == cancelled,
      scanning => next == accepted || next == rejected,
      accepted || rejected || expired || cancelled => false,
    };
  }
}
