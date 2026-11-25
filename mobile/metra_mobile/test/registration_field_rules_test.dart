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
    test('rejects blank, too short, and overlong', () {
      expect(RegistrationFieldRules.requiredName('  '), isNotNull);
      expect(RegistrationFieldRules.requiredName('أ'), isNotNull);
      expect(RegistrationFieldRules.requiredName('x' * 81), isNotNull);
    });

    test('accepts normal name', () {
      expect(RegistrationFieldRules.requiredName('أحمد'), isNull);
    });
  });

  group('RegistrationFieldRules.optionalEmail', () {
    test('allows empty', () {
      expect(RegistrationFieldRules.optionalEmail(null), isNull);
      expect(RegistrationFieldRules.optionalEmail(''), isNull);
      expect(RegistrationFieldRules.optionalEmail('   '), isNull);
    });

    test('rejects malformed and overlong', () {
      expect(RegistrationFieldRules.optionalEmail('not-an-email'), isNotNull);
      expect(RegistrationFieldRules.optionalEmail('a@'), isNotNull);
      expect(
        RegistrationFieldRules.optionalEmail('${'a' * 250}@x.com'),
        isNotNull,
      );
    });

    test('accepts plausible addresses', () {
      expect(RegistrationFieldRules.optionalEmail('user@example.com'), isNull);
      expect(
        RegistrationFieldRules.optionalEmail('ops.team+metra@meteo.gov.sy'),
        isNull,
      );
    });
  });

  group('RegistrationFieldRules.password', () {
    test('rejects empty, whitespace-only, short, and overlong', () {
      expect(RegistrationFieldRules.password(null), isNotNull);
      expect(RegistrationFieldRules.password(''), isNotNull);
      expect(RegistrationFieldRules.password('   '), isNotNull);
      expect(RegistrationFieldRules.password('short'), isNotNull);
      expect(RegistrationFieldRules.password('x' * 129), isNotNull);
    });

    test('accepts length 8-128', () {
      expect(RegistrationFieldRules.password('password'), isNull);
      expect(RegistrationFieldRules.password('x' * 128), isNull);
    });
  });

  group('RegistrationFieldRules.confirmPassword', () {
    test('requires confirmation and match', () {
      expect(
        RegistrationFieldRules.confirmPassword('secret12', null),
        isNotNull,
      );
      expect(RegistrationFieldRules.confirmPassword('secret12', ''), isNotNull);
      expect(
        RegistrationFieldRules.confirmPassword('secret12', 'secret13'),
        isNotNull,
      );
    });

    test('accepts matching pair', () {
      expect(
        RegistrationFieldRules.confirmPassword('secret12', 'secret12'),
        isNull,
      );
    });
  });
}
