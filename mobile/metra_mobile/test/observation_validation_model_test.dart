import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/models/observation_validation.dart';

void main() {
  test('parses a valid response with no issues', () {
    final result = ObservationValidationResult.fromJson({
      'isValid': true,
      'issues': <Object>[],
    });

    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
  });

  test('parses an invalid response and preserves field messages', () {
    final result = ObservationValidationResult.fromJson({
      'isValid': false,
      'issues': [
        {'field': 'dryTemp', 'message': 'درجة الحرارة خارج المجال.'},
      ],
    });

    expect(result.isValid, isFalse);
    expect(result.issues.single.field, 'dryTemp');
    expect(result.issues.single.message, 'درجة الحرارة خارج المجال.');
  });

  test('rejects missing response properties', () {
    expect(
      () => ObservationValidationResult.fromJson({'issues': []}),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects malformed issue entries instead of silently dropping them', () {
    expect(
      () => ObservationValidationResult.fromJson({
        'isValid': false,
        'issues': [null],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects issues without a field or message', () {
    expect(
      () => ObservationValidationResult.fromJson({
        'isValid': false,
        'issues': [{'field': 'dryTemp'}],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a valid response that also contains issues', () {
    expect(
      () => ObservationValidationResult.fromJson({
        'isValid': true,
        'issues': [{'field': 'dryTemp', 'message': 'Invalid.'}],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects an invalid response without any issues', () {
    expect(
      () => ObservationValidationResult.fromJson({
        'isValid': false,
        'issues': [],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
