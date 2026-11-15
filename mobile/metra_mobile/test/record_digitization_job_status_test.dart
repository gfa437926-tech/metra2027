import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/records/record_digitization_job_status.dart';

void main() {
  group('RecordDigitizationJobStatus wire parsing', () {
    test('parses all documented states', () {
      for (final status in RecordDigitizationJobStatus.values) {
        expect(RecordDigitizationJobStatus.tryParse(status.name), status);
      }
    });

    test('fails closed for unknown or non-string states', () {
      expect(RecordDigitizationJobStatus.tryParse('processing'), isNull);
      expect(RecordDigitizationJobStatus.tryParse(null), isNull);
      expect(RecordDigitizationJobStatus.tryParse(3), isNull);
    });
  });

  group('RecordDigitizationJobStatus transitions', () {
    test('allows documented forward transitions', () {
      expect(RecordDigitizationJobStatus.queued
          .canTransitionTo(RecordDigitizationJobStatus.validating), isTrue);
      expect(RecordDigitizationJobStatus.queued
          .canTransitionTo(RecordDigitizationJobStatus.cancelled), isTrue);
      expect(RecordDigitizationJobStatus.validating
          .canTransitionTo(RecordDigitizationJobStatus.running), isTrue);
      expect(RecordDigitizationJobStatus.validating
          .canTransitionTo(RecordDigitizationJobStatus.failed), isTrue);
      expect(RecordDigitizationJobStatus.running
          .canTransitionTo(RecordDigitizationJobStatus.succeeded), isTrue);
      expect(RecordDigitizationJobStatus.running
          .canTransitionTo(RecordDigitizationJobStatus.cancelled), isTrue);
    });

    test('rejects skipped transitions and terminal state mutation', () {
      expect(RecordDigitizationJobStatus.queued
          .canTransitionTo(RecordDigitizationJobStatus.running), isFalse);
      expect(RecordDigitizationJobStatus.validating
          .canTransitionTo(RecordDigitizationJobStatus.succeeded), isFalse);
      for (final terminal in [
        RecordDigitizationJobStatus.succeeded,
        RecordDigitizationJobStatus.failed,
        RecordDigitizationJobStatus.cancelled,
      ]) {
        expect(terminal.isTerminal, isTrue);
        expect(terminal.canTransitionTo(RecordDigitizationJobStatus.running),
            isFalse);
      }
    });

    test('rejects same-state transitions', () {
      for (final status in RecordDigitizationJobStatus.values) {
        expect(status.canTransitionTo(status), isFalse);
      }
    });
  });
}
