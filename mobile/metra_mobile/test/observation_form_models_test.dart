import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/observations/observation_form_models.dart';

void main() {
  group('HourlyObservationFormModel', () {
    test('requires precipitation only at the four synoptic hours', () {
      for (final hour in ['00', '06', '12', '18']) {
        final model = HourlyObservationFormModel(utcTime: hour, values: const {});
        expect(model.missingRequiredCodes(), contains('precipitationAmount'));
      }
      for (final hour in ['01', '03', '09', '15', '21', '23']) {
        final model = HourlyObservationFormModel(utcTime: hour, values: const {});
        expect(model.missingRequiredCodes(), isNot(contains('precipitationAmount')));
      }
    });

    test('requires pressure tendency fields at the eight defined UTC hours', () {
      for (final hour in ['00', '03', '06', '09', '12', '15', '18', '21']) {
        final model = HourlyObservationFormModel(utcTime: hour, values: const {});
        expect(model.missingRequiredCodes(), contains('pressureSlope'));
        expect(model.missingRequiredCodes(), contains('pressureShape'));
      }
      for (final hour in ['01', '02', '04', '05', '07', '23']) {
        final model = HourlyObservationFormModel(utcTime: hour, values: const {});
        expect(model.missingRequiredCodes(), isNot(contains('pressureSlope')));
        expect(model.missingRequiredCodes(), isNot(contains('pressureShape')));
      }
    });

    test('serializes meteorological fields only and keeps blank fields absent', () {
      const model = HourlyObservationFormModel(
        utcTime: '12',
        values: {'dryTemp': '+21', 'observerNotes': 'ملاحظة خارج الحمولة'},
      );
      final payload = model.toPayload();
      expect(payload['utcTime'], '12');
      expect(payload['dryTemp'], '+21');
      expect(payload.containsKey('observerNotes'), isFalse);
    });
  });

  group('DailyObservationFormModel', () {
    test('supports the three original report types', () {
      expect(DailyObservationFormModel.reportTypes.keys,
          containsAll(['24h', '06utc', '18utc']));
    });

    test('keeps report type and meteorological values in a separate payload', () {
      const model = DailyObservationFormModel(
        reportType: '24h',
        values: {'minTemp': '-2', 'thunderstorm': 'true'},
      );
      final payload = model.toPayload();
      expect(payload['reportType'], '24h');
      expect(payload['minTemp'], '-2');
      expect(payload['thunderstorm'], isTrue);
      expect(payload.containsKey('observerNotes'), isFalse);
    });

    test('does not claim unresolved daily required-field policy', () {
      const model = DailyObservationFormModel(reportType: '06utc', values: {});
      expect(model.unresolvedContractQuestions, isNotEmpty);
    });
  });
}
