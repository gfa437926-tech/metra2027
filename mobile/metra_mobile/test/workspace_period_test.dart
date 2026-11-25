import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/workspaces/workspace_period.dart';

void main() {
  group('workspacePeriodError', () {
    test('null bounds are not errors', () {
      expect(workspacePeriodError(null, null), isNull);
      expect(workspacePeriodError(DateTime(2024, 1, 1), null), isNull);
      expect(workspacePeriodError(null, DateTime(2024, 1, 2)), isNull);
    });

    test('rejects inverted range', () {
      final err = workspacePeriodError(
        DateTime(2024, 6, 10),
        DateTime(2024, 6, 1),
      );
      expect(err, isNotNull);
      expect(err, contains('أسبق'));
    });

    test('rejects future end day', () {
      final tomorrow = DateTime.now().add(const Duration(days: 2));
      final err = workspacePeriodError(DateTime(2024, 1, 1), tomorrow);
      expect(err, isNotNull);
      expect(err, contains('المستقبل'));
    });

    test('rejects span longer than ~5 years', () {
      final err = workspacePeriodError(
        DateTime(2015, 1, 1),
        DateTime(2024, 1, 1),
      );
      expect(err, isNotNull);
      expect(err, contains('خمس سنوات'));
    });

    test('accepts same-day and short past ranges', () {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      expect(workspacePeriodError(day, day), isNull);
      expect(
        workspacePeriodError(DateTime(2023, 1, 1), DateTime(2023, 12, 31)),
        isNull,
      );
    });
  });

  group('workspacePeriodDayCount', () {
    test('null when incomplete or invalid', () {
      expect(workspacePeriodDayCount(null, DateTime(2024, 1, 2)), isNull);
      expect(
        workspacePeriodDayCount(DateTime(2024, 6, 10), DateTime(2024, 6, 1)),
        isNull,
      );
    });

    test('inclusive day count for valid range', () {
      expect(
        workspacePeriodDayCount(DateTime(2023, 1, 1), DateTime(2023, 1, 1)),
        1,
      );
      expect(
        workspacePeriodDayCount(DateTime(2023, 1, 1), DateTime(2023, 1, 10)),
        10,
      );
    });
  });

  group('workspacePeriodIsReady', () {
    test('false until both bounds valid', () {
      expect(workspacePeriodIsReady(null, null), isFalse);
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      expect(workspacePeriodIsReady(day, day), isTrue);
    });
  });
}
