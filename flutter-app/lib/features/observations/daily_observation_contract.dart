/// Client-side mirror of the METRA daily observation v1 field contract.
/// The API remains authoritative; all meteorological codes stay strings.
class DailyObservationField {
  const DailyObservationField(this.key, this.label, this.pattern, this.min, this.max);
  final String key;
  final String label;
  final String pattern;
  final double min;
  final double max;
}

class DailyObservationContract {
  static const reportTypes = <String, String>{
    '24h': 'نشرة يومية كاملة (24 ساعة)',
    '06utc': 'نشرة الرصد عند 06 UTC',
    '18utc': 'نشرة الرصد عند 18 UTC',
  };

  static const fields = <DailyObservationField>[
    DailyObservationField('minTemp', 'درجة الحرارة الصغرى (مثل -05.3)', r'^-?\d{2}\.\d$', -20, 50),
    DailyObservationField('maxTemp', 'درجة الحرارة العظمى (مثل 25.7)', r'^-?\d{2}\.\d$', -20, 50),
    DailyObservationField('precipitation', 'الهطول (مثل 012.5)', r'^\d{3}\.\d$', 0, 999.9),
    DailyObservationField('snowThickness', 'سماكة الثلج (ثلاث خانات)', r'^\d{3}$', 0, 999),
    DailyObservationField('evaporation', 'التبخر (مثل 12.5)', r'^\d{2}\.\d$', 0, 99.9),
    DailyObservationField('sunshineDuration', 'مدة سطوع الشمس (مثل 08.5)', r'^\d{2}\.\d$', 0, 24),
    DailyObservationField('sunshinePercentage', 'نسبة سطوع الشمس (000–100)', r'^\d{3}$', 0, 100),
    DailyObservationField('maxGustSpeed', 'سرعة هبات الرياح (خانتان)', r'^\d{2}$', 0, 36),
    DailyObservationField('maxGustDirection', 'اتجاه هبات الرياح (00–36)', r'^\d{2}$', 0, 36),
    DailyObservationField('maxGustTime', 'وقت هبة الرياح العظمى (HH.t)', r'^\d{2}\.\d$', 0, 23.9),
    DailyObservationField('maxHumidity', 'الرطوبة العظمى (000–100)', r'^\d{3}$', 0, 100),
    DailyObservationField('maxHumidityTime', 'وقت الرطوبة العظمى (HH.t)', r'^\d{2}\.\d$', 0, 23.9),
    DailyObservationField('minHumidity', 'الرطوبة الصغرى (خانتان)', r'^\d{2}$', 0, 99),
    DailyObservationField('minHumidityTime', 'وقت الرطوبة الصغرى (HH.t)', r'^\d{2}\.\d$', 0, 23.9),
  ];

  static const _fullDay = <String>{
    'minTemp', 'maxTemp', 'precipitation', 'evaporation',
    'sunshineDuration', 'sunshinePercentage', 'maxGustSpeed',
    'maxGustDirection', 'maxGustTime', 'maxHumidity', 'maxHumidityTime',
    'minHumidity', 'minHumidityTime',
  };
  static const _synoptic = <String>{
    'minTemp', 'maxTemp', 'precipitation',
  };

  static Set<String> requiredFields(String reportType) => switch (reportType) {
    '24h' => _fullDay,
    '06utc' || '18utc' => _synoptic,
    _ => const <String>{},
  };

  static String? validateField(String key, String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return 'هذا الحقل مطلوب؛ استخدم # إذا تعذرت القراءة';
    if (value == '#') return null;
    if (key == 'precipitationTrace') {
      return RegExp(r'^[Tt]$').hasMatch(value) ? null : 'أدخل T أو t';
    }
    DailyObservationField? field;
    for (final candidate in fields) {
      if (candidate.key == key) {
        field = candidate;
        break;
      }
    }
    if (field == null) return null;
    if (!RegExp(field.pattern).hasMatch(value)) {
      return 'تنسيق ${field.label} غير صحيح';
    }
    final number = double.tryParse(value);
    if (number == null || number < field.min || number > field.max) {
      return 'قيمة ${field.label} خارج المجال المسموح';
    }
    return null;
  }

  static Map<String, String> validate(
    String reportType,
    Map<String, String> values, {
    required bool responsibilityAgreement,
  }) {
    final errors = <String, String>{};
    if (!reportTypes.containsKey(reportType)) {
      errors['reportType'] = 'نوع النشرة غير صالح';
      return errors;
    }
    if (!responsibilityAgreement) {
      errors['responsibilityAgreement'] = 'يجب تأكيد إقرار المسؤولية';
    }
    for (final key in requiredFields(reportType)) {
      final error = validateField(key, values[key]);
      if (error != null) errors[key] = error;
    }
    if ((values['precipitationTrace'] ?? '').trim().isNotEmpty) {
      final error = validateField('precipitationTrace', values['precipitationTrace']);
      if (error != null) errors['precipitationTrace'] = error;
    }
    final minTemp = double.tryParse(values['minTemp'] ?? '');
    final maxTemp = double.tryParse(values['maxTemp'] ?? '');
    if (minTemp != null && maxTemp != null && maxTemp < minTemp) {
      errors['maxTemp'] = 'الحرارة العظمى يجب ألا تقل عن الصغرى';
    }
    final maxHumidity = int.tryParse(values['maxHumidity'] ?? '');
    final minHumidity = int.tryParse(values['minHumidity'] ?? '');
    if (maxHumidity != null && minHumidity != null && minHumidity > maxHumidity) {
      errors['minHumidity'] = 'الرطوبة الصغرى يجب ألا تتجاوز العظمى';
    }
    return errors;
  }
}
