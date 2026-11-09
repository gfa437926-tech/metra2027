import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/observations/daily_observation_contract.dart';

/// Mirrors contracts/observation-v1 daily fixtures without filesystem lookup in CI.
void main() {
  test('daily 24h valid fixture matches DailyObservationContract', () {
    final errors = DailyObservationContract.validate(
      '24h',
      {
        'minTemp': '12.5',
        'maxTemp': '28.0',
        'precipitation': '012.5',
        'snowThickness': '000',
        'evaporation': '03.2',
        'sunshineDuration': '08.5',
        'sunshinePercentage': '070',
        'maxGustSpeed': '12',
        'maxGustDirection': '18',
        'maxGustTime': '14.5',
        'maxHumidity': '085',
        'maxHumidityTime': '06.0',
        'minHumidity': '35',
        'minHumidityTime': '15.0',
      },
      responsibilityAgreement: true,
    );
    expect(errors, isEmpty, reason: '$errors');
  });

  test('daily 06utc valid fixture matches DailyObservationContract', () {
    final errors = DailyObservationContract.validate(
      '06utc',
      {
        'minTemp': '08.0',
        'maxTemp': '19.5',
        'precipitation': '000.0',
        'snowThickness': '000',
      },
      responsibilityAgreement: true,
    );
    expect(errors, isEmpty, reason: '$errors');
  });

  test('daily max < min is rejected on maxTemp', () {
    final errors = DailyObservationContract.validate(
      '06utc',
      {
        'minTemp': '20.0',
        'maxTemp': '10.0',
        'precipitation': '000.0',
        'snowThickness': '000',
      },
      responsibilityAgreement: true,
    );
    expect(errors.containsKey('maxTemp'), isTrue, reason: '$errors');
  });

  test('daily submission requires responsibility agreement', () {
    final errors = DailyObservationContract.validate(
      '06utc',
      {
        'minTemp': '08.0',
        'maxTemp': '19.5',
        'precipitation': '000.0',
        'snowThickness': '000',
      },
      responsibilityAgreement: false,
    );
    expect(errors.containsKey('responsibilityAgreement'), isTrue);
  });

  test('daily missing markers with # are accepted for required fields', () {
    final errors = DailyObservationContract.validate(
      '06utc',
      {
        'minTemp': '#',
        'maxTemp': '#',
        'precipitation': '#',
        'snowThickness': '#',
      },
      responsibilityAgreement: true,
    );
    expect(errors, isEmpty, reason: '$errors');
  });
}
