/// Client-side mirror of the canonical hourly observation v1 contract.
/// The .NET API remains authoritative; meteorological codes are kept as strings.
class HourlyObservationField {
  const HourlyObservationField(this.key, this.pattern, this.min, this.max);
  final String key;
  final String pattern;
  final double min;
  final double max;
}

class HourlyObservationContract {
  static const alwaysRequired = <String>{
    'dryTemp', 'wetTemp', 'stationPressure', 'seaLevelPressure',
    'windDirection', 'windSpeed', 'visibility', 'totalCloudCover',
    'relativeHumidity', 'dewPoint', 'cover12', 'cover123',
  };
  static const synopticHours = <int>{0, 3, 6, 9, 12, 15, 18, 21};
  static const precipitationHours = <int>{0, 6, 12, 18};

  static const fields = <HourlyObservationField>[
    HourlyObservationField('dryTemp', r'^[+-]\d{2}\.\d$', -20, 50),
    HourlyObservationField('wetTemp', r'^[+-]\d{2}\.\d$', -20, 50),
    HourlyObservationField('dewPoint', r'^[+-]\d{2}\.\d$', -20, 50),
    HourlyObservationField('stationPressure', r'^\d{4}\.\d$', 850, 1050),
    HourlyObservationField('seaLevelPressure', r'^\d{4}\.\d$', 0, 1050),
    HourlyObservationField('relativeHumidity', r'^\d{3}$', 1, 100),
    HourlyObservationField('vaporPressure', r'^\d{2}\.\d$', 0, 99),
    HourlyObservationField('vaporPressureDiff', r'^\d{2}\.\d$', 0, 99),
    HourlyObservationField('windDirection', r'^\d{2}$', 0, 36),
    HourlyObservationField('avgWindDirection', r'^\d{2}$', 0, 36),
    HourlyObservationField('windSpeed', r'^\d{2}$', 0, 99),
    HourlyObservationField('avgWindSpeed', r'^\d{2}$', 0, 99),
    HourlyObservationField('visibility', r'^\d{3}$', 0, 200),
    HourlyObservationField('currentWeather', r'^\d{2}$', 0, 99),
    HourlyObservationField('pastWeather', r'^\d$', 0, 9),
    HourlyObservationField('totalCloudCover', r'^\d$', 0, 8),
    HourlyObservationField('cloud1Amount', r'^[0-8]$', 0, 8),
    HourlyObservationField('cloud2Amount', r'^[0-8]$', 0, 8),
    HourlyObservationField('cloud3Amount', r'^[0-8]$', 0, 8),
    HourlyObservationField('cloud4Amount', r'^[0-8]$', 0, 8),
    HourlyObservationField('cloud1Height', r'^\d{1,3}$', 0, 999),
    HourlyObservationField('cloud2Height', r'^\d{1,3}$', 0, 999),
    HourlyObservationField('cloud3Height', r'^\d{1,3}$', 0, 999),
    HourlyObservationField('cover12', r'^[0-8]$', 0, 8),
    HourlyObservationField('cover123', r'^[0-8]$', 0, 8),
    HourlyObservationField('pressureSlope', r'^\d{1,2}\.\d$', 0, 99),
    HourlyObservationField('pressureShape', r'^[0-8]$', 0, 8),
    HourlyObservationField('precipitationAmount', r'^\d{3}\.\d$', 0, 999.9),
  ];

  static Map<String, String> validate(Map<String, String> values) {
    final errors = <String, String>{};
    final rawHour = values['utcTime']?.trim() ?? '';
    if (!RegExp(r'^\d{2}$').hasMatch(rawHour)) {
      errors['utcTime'] = 'ساعة الرصد بالتوقيت العالمي مطلوبة ويجب أن تكون من 00 إلى 23';
      return errors;
    }
    final hour = int.tryParse(rawHour);
    if (hour == null || hour < 0 || hour > 23) {
      errors['utcTime'] = 'ساعة الرصد بالتوقيت العالمي غير صالحة';
      return errors;
    }

    final required = <String>{...alwaysRequired};
    if (precipitationHours.contains(hour)) required.add('precipitationAmount');
    if (synopticHours.contains(hour)) {
      required.addAll({'pressureSlope', 'pressureShape', 'pastWeather'});
    }
    for (final key in required) {
      final value = values[key]?.trim() ?? '';
      if (value.isEmpty) errors[key] = 'هذا الحقل مطلوب';
    }

    for (final field in fields) {
      final value = values[field.key]?.trim() ?? '';
      if (value.isEmpty || value == '#') continue;
      if (!RegExp(field.pattern).hasMatch(value)) {
        errors[field.key] = 'تنسيق الحقل غير صحيح';
        continue;
      }
      final number = double.tryParse(value);
      if (number == null || number < field.min || number > field.max) {
        errors[field.key] = 'القيمة خارج المجال المسموح';
      }
    }

    final dry = double.tryParse(values['dryTemp']?.trim() ?? '');
    final wet = double.tryParse(values['wetTemp']?.trim() ?? '');
    if (dry != null && wet != null &&
        values['dryTemp'] != '#' && values['wetTemp'] != '#' && dry < wet) {
      errors['dryTemp'] = 'الحرارة الجافة يجب أن تكون أكبر من أو تساوي الحرارة الرطبة';
    }
    return errors;
  }
}
