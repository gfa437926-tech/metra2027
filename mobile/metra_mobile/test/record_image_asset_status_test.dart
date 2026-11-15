import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/records/record_image_asset_status.dart';

void main() {
  test('parses only known wire states', () {
    expect(RecordImageAssetStatus.tryParse('uploadedQuarantined'),
        RecordImageAssetStatus.uploadedQuarantined);
    expect(RecordImageAssetStatus.tryParse('unknown'), isNull);
    expect(RecordImageAssetStatus.tryParse(3), isNull);
  });

  test('allows only forward transitions through quarantine and scanning', () {
    expect(RecordImageAssetStatus.awaitingUpload.canTransitionTo(
        RecordImageAssetStatus.uploadedQuarantined), isTrue);
    expect(RecordImageAssetStatus.uploadedQuarantined.canTransitionTo(
        RecordImageAssetStatus.scanning), isTrue);
    expect(RecordImageAssetStatus.scanning.canTransitionTo(
        RecordImageAssetStatus.accepted), isTrue);
    expect(RecordImageAssetStatus.scanning.canTransitionTo(
        RecordImageAssetStatus.rejected), isTrue);
  });

  test('does not expose quarantined or scanning assets as evidence', () {
    expect(RecordImageAssetStatus.awaitingUpload.isAvailableEvidence, isFalse);
    expect(RecordImageAssetStatus.uploadedQuarantined.isAvailableEvidence, isFalse);
    expect(RecordImageAssetStatus.scanning.isAvailableEvidence, isFalse);
    expect(RecordImageAssetStatus.accepted.isAvailableEvidence, isTrue);
  });

  test('rejects skipped transitions, same-state transitions and terminal reopening', () {
    expect(RecordImageAssetStatus.awaitingUpload.canTransitionTo(
        RecordImageAssetStatus.accepted), isFalse);
    expect(RecordImageAssetStatus.uploadedQuarantined.canTransitionTo(
        RecordImageAssetStatus.accepted), isFalse);
    expect(RecordImageAssetStatus.scanning.canTransitionTo(
        RecordImageAssetStatus.expired), isFalse);
    expect(RecordImageAssetStatus.accepted.canTransitionTo(
        RecordImageAssetStatus.scanning), isFalse);
    expect(RecordImageAssetStatus.rejected.canTransitionTo(
        RecordImageAssetStatus.accepted), isFalse);
  });
}
