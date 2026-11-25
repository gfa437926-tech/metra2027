import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/auth/registration_field_rules.dart';

void main() {
  group('RegistrationFieldRules.stationId', () {
    test('rejects empty and non-uuid', () {
      expect(RegistrationFieldRules.stationId(null), isNotNull);
      expect(RegistrationFieldRules.stationId(''), isNotNull);
      expect(RegistrationFieldRules.stationId('ST-01'), isNotNull);
    });

    test('accepts uuid', () {
      expect(
        RegistrationFieldRules.stationId(
          '11111111-1111-4111-8111-111111111111',
        ),
        isNull,
      );
    });
  });

  group('RegistrationFieldRules.phone', () {
    test('rejects short and alpha', () {
      expect(RegistrationFieldRules.phone('123'), isNotNull);
      expect(RegistrationFieldRules.phone('abc'), isNotNull);
    });

    test('accepts 8-15 digits with separators', () {
      expect(RegistrationFieldRules.phone('0912345678'), isNull);
      expect(RegistrationFieldRules.phone('+963 912-345-678'), isNull);
    });
  });

  group('RegistrationFieldRules.requiredName', () {
    test('rejects blank and overlong', () {
      expect(RegistrationFieldRules.requiredName('  '), isNotNull);
      expect(RegistrationFieldRules.requiredName('x' * 81), isNotNull);
    });

    test('accepts normal name', () {
      expect(RegistrationFieldRules.requiredName('أحمد'), isNull);
    });
  });
}
