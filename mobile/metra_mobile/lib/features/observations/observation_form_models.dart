import 'package:flutter/foundation.dart';

/// Source-derived field catalog for the legacy METRA observation forms.
/// This catalog intentionally does not invent server-required rules.
@immutable
class ObservationField {
  const ObservationField(this.code, this.label, {this.numeric = false, this.boolean = false});
  final String code;
  final String label;
  final bool numeric;
  final bool boolean;
}

class HourlyObservationFormModel {
  static const fields = <ObservationField>[
    ObservationField('dryTemp', 'درجة الحرارة الجافة', numeric: true),
    ObservationField('wetTemp', 'درجة الحرارة الرطبة', numeric: true),
    ObservationField('stationPressure', 'ضغط المحطة', numeric: true),
    ObservationField('seaLevelPressure', 'الضغط عند مستوى سطح البحر', numeric: true),
    ObservationField('pressureSlope', 'ميل الضغط', numeric: true),
    ObservationField('pressureShape', 'شكل تغير الضغط'),
    ObservationField('relativeHumidity', 'الرطوبة النسبية', numeric: true),
    ObservationField('vaporPressure', 'ضغط البخار', numeric: true),
    ObservationField('dewPoint', 'درجة الندى', numeric: true),
    ObservationField('vaporPressureDiff', 'فرق ضغط البخار', numeric: true),
    ObservationField('windDirection', 'اتجاه الرياح'),
    ObservationField('windSpeed', 'سرعة الرياح', numeric: true),
    ObservationField('avgWindDirection', 'متوسط اتجاه الرياح'),
    ObservationField('avgWindSpeed', 'متوسط سرعة الرياح', numeric: true),
    ObservationField('visibility', 'مدى الرؤية'),
    ObservationField('currentWeather', 'الطقس الحالي'),
    ObservationField('pastWeather', 'الطقس السابق'),
    ObservationField('precipitationAmount', 'كمية الهطول', numeric: true),
    ObservationField('totalCloudCover', 'الغطاء السحابي الكلي'),
    ObservationField('cloud1Amount', 'كمية الغيوم - الطبقة الأولى'),
    ObservationField('cloud1Type', 'نوع الغيوم - الطبقة الأولى'),
    ObservationField('cloud1Height', 'ارتفاع الغيوم - الطبقة الأولى', numeric: true),
    ObservationField('cloud2Amount', 'كمية الغيوم - الطبقة الثانية'),
    ObservationField('cloud2Type', 'نوع الغيوم - الطبقة الثانية'),
    ObservationField('cloud2Height', 'ارتفاع الغيوم - الطبقة الثانية', numeric: true),
    ObservationField('cloud3Amount', 'كمية الغيوم - الطبقة الثالثة'),
    ObservationField('cloud3Type', 'نوع الغيوم - الطبقة الثالثة'),
    ObservationField('cloud3Height', 'ارتفاع الغيوم - الطبقة الثالثة', numeric: true),
    ObservationField('cloud4Amount', 'كمية الغيوم - الطبقة الرابعة'),
    ObservationField('cover12', 'الغطاء السحابي للطبقتين الأولى والثانية'),
    ObservationField('cover123', 'الغطاء السحابي للطبقات الثلاث'),
  ];

  static const requiredBaseCodes = <String>{
    'dryTemp', 'wetTemp', 'stationPressure', 'seaLevelPressure',
    'windDirection', 'windSpeed', 'visibility', 'totalCloudCover',
    'relativeHumidity', 'dewPoint',
  };

  static const precipitationHours = <String>{'00', '06', '12', '18'};
  static const pressureHours = <String>{'00', '03', '06', '09', '12', '15', '18', '21'};

  final String utcTime;
  final Map<String, String> values;
  const HourlyObservationFormModel({required this.utcTime, required this.values});

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'utcTime': utcTime,
    for (final field in fields)
      if ((values[field.code] ?? '').trim().isNotEmpty)
        field.code: values[field.code]!.trim(),
  };

  List<String> missingRequiredCodes() {
    final missing = <String>[
      for (final code in requiredBaseCodes)
        if ((values[code] ?? '').trim().isEmpty) code,
      if (precipitationHours.contains(utcTime) &&
          (values['precipitationAmount'] ?? '').trim().isEmpty)
        'precipitationAmount',
      if (pressureHours.contains(utcTime)) ...[
        if ((values['pressureSlope'] ?? '').trim().isEmpty) 'pressureSlope',
        if ((values['pressureShape'] ?? '').trim().isEmpty) 'pressureShape',
      ],
    ];
    return missing;
  }
}

class DailyObservationFormModel {
  static const fields = <ObservationField>[
    ObservationField('minTemp', 'درجة الحرارة الصغرى', numeric: true),
    ObservationField('maxTemp', 'درجة الحرارة العظمى', numeric: true),
    ObservationField('precipitation', 'كمية الهطول', numeric: true),
    ObservationField('snowThickness', 'أكبر سماكة للثلج', numeric: true),
    ObservationField('precipitationTrace', 'أثر الهطول'),
    ObservationField('thunderstorm', 'عواصف رعدية', boolean: true),
    ObservationField('hail', 'برد', boolean: true),
    ObservationField('snow', 'ثلج', boolean: true),
    ObservationField('rain', 'مطر', boolean: true),
    ObservationField('frost', 'صقيع', boolean: true),
    ObservationField('fog', 'ضباب', boolean: true),
    ObservationField('mist', 'شابورة', boolean: true),
    ObservationField('dustStorm', 'عواصف ترابية أو رملية', boolean: true),
    ObservationField('blowingDust', 'غبار متصاعد', boolean: true),
    ObservationField('haze', 'سديم', boolean: true),
    ObservationField('stormyWind', 'رياح عاصفة', boolean: true),
    ObservationField('evaporation', 'مجموع التبخر اليومي', numeric: true),
    ObservationField('sunshineDuration', 'مدة سطوع الشمس', numeric: true),
    ObservationField('sunshinePercentage', 'النسبة المئوية لسطوع الشمس', numeric: true),
    ObservationField('maxGustSpeed', 'أكبر نفحة للرياح', numeric: true),
    ObservationField('maxGustDirection', 'اتجاه أكبر نفحة', numeric: true),
    ObservationField('maxGustTime', 'وقت أكبر نفحة'),
    ObservationField('maxHumidity', 'أكبر رطوبة نسبية', numeric: true),
    ObservationField('maxHumidityTime', 'وقت أكبر رطوبة'),
    ObservationField('minHumidity', 'أصغر رطوبة نسبية', numeric: true),
    ObservationField('minHumidityTime', 'وقت أصغر رطوبة'),
  ];

  static const reportTypes = <String, String>{
    '24h': 'تقرير يومي 24 ساعة',
    '06utc': 'تقرير 06 UTC',
    '18utc': 'تقرير 18 UTC',
  };

  final String reportType;
  final Map<String, String> values;
  const DailyObservationFormModel({required this.reportType, required this.values});

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'reportType': reportType,
    for (final field in fields)
      if ((values[field.code] ?? '').trim().isNotEmpty)
        field.code: field.boolean
            ? (values[field.code] == 'true')
            : values[field.code]!.trim(),
  };

  /// No final required-field policy is asserted until the snow-thickness
  /// conflict and server contract are approved.
  List<String> get unresolvedContractQuestions => const [
    'هل سماكة الثلج إلزامية في تقريري 06 و18 UTC؟',
    'ما الحقول الأساسية الإلزامية المعتمدة لكل نوع تقرير؟',
    'ما الحقول التي تسمح بعلامة عدم توفر البيانات (#)؟',
  ];
}
