import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/catalog_integration/rainfall_soil_local_rules.dart';

void main() {
  group('parseOptionalDecimal', () {
    test('blank is absent, not zero', () {
      final a = RainfallSoilLocalRules.parseOptionalDecimal(null);
      final b = RainfallSoilLocalRules.parseOptionalDecimal('');
      final c = RainfallSoilLocalRules.parseOptionalDecimal('  ');
      expect(a.isAbsent, isTrue);
      expect(b.isAbsent, isTrue);
      expect(c.isAbsent, isTrue);
      expect(a.isRecordedZero, isFalse);
    });

    test('zero string is recorded zero', () {
      final z = RainfallSoilLocalRules.parseOptionalDecimal('0');
      final z2 = RainfallSoilLocalRules.parseOptionalDecimal('0.0');
      expect(z.isRecordedZero, isTrue);
      expect(z2.isRecordedZero, isTrue);
      expect(z.isAbsent, isFalse);
    });

    test('positive is present non-zero', () {
      final p = RainfallSoilLocalRules.parseOptionalDecimal('12.5');
      expect(p.isPresent, isTrue);
      expect(p.isRecordedZero, isFalse);
      expect(p.value, 12.5);
    });

    test('garbage is invalid', () {
      expect(
        RainfallSoilLocalRules.parseOptionalDecimal('x').isInvalid,
        isTrue,
      );
    });
  });

  group('isValidObservationDate', () {
    test('accepts real calendar dates', () {
      expect(
        RainfallSoilLocalRules.isValidObservationDate('2026-11-18'),
        isTrue,
      );
      expect(
        RainfallSoilLocalRules.isValidObservationDate('2024-02-29'),
        isTrue,
      );
    });

    test('rejects invalid and non-ISO dates', () {
      expect(
        RainfallSoilLocalRules.isValidObservationDate('2026-02-30'),
        isFalse,
      );
      expect(
        RainfallSoilLocalRules.isValidObservationDate('18-11-2026'),
        isFalse,
      );
      expect(
        RainfallSoilLocalRules.isValidObservationDate('2026/11/18'),
        isFalse,
      );
      expect(RainfallSoilLocalRules.isValidObservationDate(''), isFalse);
    });
  });

  group('validateRainfall', () {
    test('rejects malformed and impossible calendar dates', () {
      for (final date in ['2026-2-01', '2026-02-31', '01-02-2026']) {
        final errors = RainfallSoilLocalRules.validateRainfall({
          'observationDate': date,
          'responsibilityAgreement': true,
        });
        expect(errors.containsKey('observationDate'), isTrue, reason: date);
      }
    });

    test('accepts a valid leap-day observation date', () {
      final errors = RainfallSoilLocalRules.validateRainfall({
        'observationDate': '2024-02-29',
        'responsibilityAgreement': true,
      });
      expect(errors, isEmpty);
    });
    test('requires date and agreement', () {
      final errors = RainfallSoilLocalRules.validateRainfall({});
      expect(errors.containsKey('observationDate'), isTrue);
      expect(errors.containsKey('responsibilityAgreement'), isTrue);
    });

    test('rejects impossible calendar date', () {
      final errors = RainfallSoilLocalRules.validateRainfall({
        'observationDate': '2026-02-30',
        'responsibilityAgreement': true,
      });
      expect(errors.containsKey('observationDate'), isTrue);
    });

    test('allows missing rain amount as unavailable', () {
      final errors = RainfallSoilLocalRules.validateRainfall({
        'observationDate': '2026-11-18',
        'responsibilityAgreement': true,
      });
      expect(errors, isEmpty);
    });

    test('accepts explicit zero rain amount', () {
      final errors = RainfallSoilLocalRules.validateRainfall({
        'observationDate': '2026-11-18',
        'responsibilityAgreement': true,
        'rainAmount': '0',
      });
      expect(errors, isEmpty);
    });

    test('rejects non-numeric rain amount', () {
      final errors = RainfallSoilLocalRules.validateRainfall({
        'observationDate': '2026-11-18',
        'responsibilityAgreement': true,
        'rainAmount': 'غزير',
      });
      expect(errors.containsKey('rainAmount'), isTrue);
    });

    test('rejects negative rain amount', () {
      final errors = RainfallSoilLocalRules.validateRainfall({
        'observationDate': '2026-11-18',
        'responsibilityAgreement': true,
        'rainAmount': '-1',
      });
      expect(errors.containsKey('rainAmount'), isTrue);
    });

    test('rejects future observation date', () {
      final errors = RainfallSoilLocalRules.validateRainfall({
        'observationDate': '2099-01-01',
        'responsibilityAgreement': true,
      });
      expect(errors['observationDate'], contains('المستقبل'));
    });
  });

  group('validateSoil', () {
    test('rejects impossible observation date', () {
      final errors = RainfallSoilLocalRules.validateSoil({
        'observationDate': '2026-04-31',
        'responsibilityAgreement': true,
      });
      expect(errors.containsKey('observationDate'), isTrue);
    });
    test('requires date and agreement', () {
      final errors = RainfallSoilLocalRules.validateSoil({'depth5': '18'});
      expect(errors.containsKey('observationDate'), isTrue);
      expect(errors.containsKey('responsibilityAgreement'), isTrue);
    });

    test('accepts finite depths', () {
      final errors = RainfallSoilLocalRules.validateSoil({
        'observationDate': '2026-11-18',
        'responsibilityAgreement': true,
        'depth5': '18.5',
        'depth10': '17',
      });
      expect(errors, isEmpty);
    });
  });
}
