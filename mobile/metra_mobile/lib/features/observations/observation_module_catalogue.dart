// Copyright (c) 2026 Ibrahim Zainab. All rights reserved.
// METRA Flutter field catalogue reconstructed from the legacy form controls.
// This file is a UI/domain catalogue only: it does not define API acceptance,
// validation limits, database columns, or permission to submit unsupported types.

enum ObservationModule {
  hourly,
  daily,
  agricultural,
  rainfall,
  weatherPhenomenon,
  agriculturalPhenomenon,
  soilTemperature,
  observationEquipmentFault,
  telecommunicationsFault,
  itIncident,
}

enum ObservationFieldKind { text, number, date, time, choice, boolean, multiline }

class ObservationFieldSpec {
  const ObservationFieldSpec({
    required this.key,
    required this.label,
    this.kind = ObservationFieldKind.text,
    this.unit,
    this.choices = const [],
    this.requiredBySource = false,
  });

  /// Exact control ID/name from the source form wherever one exists.
  final String key;
  final String label;
  final ObservationFieldKind kind;
  final String? unit;

  /// Populated only when the original source exposes a stable option list.
  final List<String> choices;

  /// Records HTML requiredness only; it is not a server validation decision.
  final bool requiredBySource;
}

class ObservationModuleSpec {
  const ObservationModuleSpec({
    required this.module,
    required this.title,
    required this.sourcePath,
    required this.fields,
    this.metadataFields = const [],
    this.sourceNotes = const [],
    this.apiObservationType,
    this.submitSupportedByCurrentApi = false,
  });

  final ObservationModule module;
  final String title;
  final String sourcePath;

  /// Meteorological, operational, or incident data only.
  final List<ObservationFieldSpec> fields;

  /// Notes, acknowledgement and reporter metadata are deliberately separate.
  final List<ObservationFieldSpec> metadataFields;
  final List<String> sourceNotes;

  /// Existing .NET submission endpoint currently accepts only hourly/daily/phenomenon.
  final String? apiObservationType;
  final bool submitSupportedByCurrentApi;
}

const _notes = ObservationFieldSpec(
  key: 'observerNotes',
  label: 'ملاحظات الراصد',
  kind: ObservationFieldKind.multiline,
);
const _ack = ObservationFieldSpec(
  key: 'responsibilityAgreement',
  label: 'إقرار صحة البيانات وتحمل المسؤولية',
  kind: ObservationFieldKind.boolean,
);
const _soilAck = ObservationFieldSpec(
  key: 'responsibilityConfirmed',
  label: 'إقرار صحة بيانات التربة',
  kind: ObservationFieldKind.boolean,
);
const _rainAck = ObservationFieldSpec(
  key: 'responsibilityAgreement',
  label: 'إقرار صحة النشرة المطرية',
  kind: ObservationFieldKind.boolean,
);

final observationModuleCatalogue = <ObservationModuleSpec>[
  const ObservationModuleSpec(
    module: ObservationModule.hourly,
    title: 'النشرة الساعية',
    sourcePath: 'hourly_reports.html',
    apiObservationType: 'hourly',
    submitSupportedByCurrentApi: true,
    fields: [
      const ObservationFieldSpec(key: 'utcTime', label: 'ساعة الرصد UTC', kind: ObservationFieldKind.time, requiredBySource: true),
      const ObservationFieldSpec(key: 'dryTemp', label: 'درجة الحرارة الجافة', kind: ObservationFieldKind.number, unit: '°س', requiredBySource: true),
      const ObservationFieldSpec(key: 'wetTemp', label: 'درجة الحرارة الرطبة', kind: ObservationFieldKind.number, unit: '°س', requiredBySource: true),
      const ObservationFieldSpec(key: 'stationPressure', label: 'ضغط المحطة', kind: ObservationFieldKind.number, unit: 'hPa', requiredBySource: true),
      const ObservationFieldSpec(key: 'seaLevelPressure', label: 'الضغط المحول إلى سطح البحر', kind: ObservationFieldKind.number, unit: 'hPa', requiredBySource: true),
      const ObservationFieldSpec(key: 'pressureSlope', label: 'ميل الضغط', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'pressureShape', label: 'شكل تغير الضغط', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'relativeHumidity', label: 'الرطوبة النسبية', kind: ObservationFieldKind.number, unit: '%'),
      const ObservationFieldSpec(key: 'vaporPressure', label: 'ضغط بخار الماء', kind: ObservationFieldKind.number, unit: 'hPa'),
      const ObservationFieldSpec(key: 'dewPoint', label: 'درجة الندى', kind: ObservationFieldKind.number, unit: '°س'),
      const ObservationFieldSpec(key: 'vaporPressureDiff', label: 'فرق ضغط بخار الماء عن الإشباع', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'windDirection', label: 'اتجاه الرياح السطحية', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'windSpeed', label: 'سرعة الرياح السطحية', kind: ObservationFieldKind.number, unit: 'م/ث'),
      const ObservationFieldSpec(key: 'avgWindDirection', label: 'اتجاه المتوسط الساعي للرياح', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'avgWindSpeed', label: 'سرعة المتوسط الساعي للرياح', kind: ObservationFieldKind.number, unit: 'م/ث'),
      const ObservationFieldSpec(key: 'visibility', label: 'الرؤية الأفقية', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'currentWeather', label: 'الطقس الحالي', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'pastWeather', label: 'الطقس السابق', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'precipitationAmount', label: 'كمية الهطول', kind: ObservationFieldKind.number, unit: 'مم'),
      const ObservationFieldSpec(key: 'totalCloudCover', label: 'التغطية الكلية للغيوم', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'cloud1Amount', label: 'كمية الغيوم في الطبقة الأولى', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'cloud1Type', label: 'نوع الغيوم في الطبقة الأولى', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'cloud1Height', label: 'ارتفاع قاعدة الطبقة الأولى', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'cloud2Amount', label: 'كمية الغيوم في الطبقة الثانية', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'cloud2Type', label: 'نوع الغيوم في الطبقة الثانية', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'cloud2Height', label: 'ارتفاع قاعدة الطبقة الثانية', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'cloud3Amount', label: 'كمية الغيوم في الطبقة الثالثة', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'cloud3Type', label: 'نوع الغيوم في الطبقة الثالثة', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'cloud3Height', label: 'ارتفاع قاعدة الطبقة الثالثة', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'cloud4Amount', label: 'كمية الغيوم في الطبقة الرابعة', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'cover12', label: 'مجموع تغطية الطبقتين الأولى والثانية', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'cover123', label: 'مجموع تغطية الطبقات الثلاث الأولى', kind: ObservationFieldKind.number),
    ],
    metadataFields: [_notes, _ack],
    sourceNotes: [
      'الهطول مطلوب عند 00 و06 و12 و18 UTC بحسب hourly-send.js.',
      'ميل الضغط وشكله مطلوبان عند 00 و03 و06 و09 و12 و15 و18 و21 UTC.',
      'رمز # ليس قيمة مفقودة عامة؛ يلزم تعريفه لكل حقل.',
    ],
  ),
  ObservationModuleSpec(
    module: ObservationModule.daily,
    title: 'النشرة اليومية',
    sourcePath: 'daily.html',
    apiObservationType: 'daily',
    submitSupportedByCurrentApi: true,
    fields: [
      const ObservationFieldSpec(key: 'currentDate', label: 'تاريخ التقرير', kind: ObservationFieldKind.date, requiredBySource: true),
      const ObservationFieldSpec(key: 'reportType', label: 'نوع التقرير', kind: ObservationFieldKind.choice, choices: ['24h', '06utc', '18utc'], requiredBySource: true),
      const ObservationFieldSpec(key: 'minTemp', label: 'درجة الحرارة الصغرى', kind: ObservationFieldKind.number, unit: '°س', requiredBySource: true),
      const ObservationFieldSpec(key: 'maxTemp', label: 'درجة الحرارة العظمى', kind: ObservationFieldKind.number, unit: '°س', requiredBySource: true),
      const ObservationFieldSpec(key: 'precipitation', label: 'كمية الهطول', kind: ObservationFieldKind.number, unit: 'مم', requiredBySource: true),
      const ObservationFieldSpec(key: 'snowThickness', label: 'أكبر سماكة للثلج', kind: ObservationFieldKind.number, unit: 'سم', requiredBySource: true),
      const ObservationFieldSpec(key: 'precipitationTrace', label: 'أثر الهطول', kind: ObservationFieldKind.choice, choices: ['T']),
      ...[
        ['thunderstorm', 'عواصف رعدية'], ['hail', 'برد'], ['snow', 'ثلج'],
        ['rain', 'مطر'], ['frost', 'صقيع'], ['fog', 'ضباب'], ['mist', 'شابورة'],
        ['dustStorm', 'عواصف ترابية أو رملية'], ['blowingDust', 'غبار متصاعد'],
        ['haze', 'سديم'], ['stormyWind', 'رياح عاصفة'],
      ].map((e) => ObservationFieldSpec(key: e[0], label: e[1], kind: ObservationFieldKind.boolean)),
      const ObservationFieldSpec(key: 'evaporation', label: 'التبخر اليومي', kind: ObservationFieldKind.number, unit: 'مم'),
      const ObservationFieldSpec(key: 'sunshineDuration', label: 'مدة سطوع الشمس', kind: ObservationFieldKind.number, unit: 'ساعة'),
      const ObservationFieldSpec(key: 'sunshinePercentage', label: 'النسبة المئوية لسطوع الشمس', kind: ObservationFieldKind.number, unit: '%'),
      const ObservationFieldSpec(key: 'maxGustSpeed', label: 'أكبر نفحة للرياح', kind: ObservationFieldKind.number, unit: 'م/ث'),
      const ObservationFieldSpec(key: 'maxGustDirection', label: 'اتجاه أكبر نفحة', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'maxGustTime', label: 'وقت أكبر نفحة', kind: ObservationFieldKind.time),
      const ObservationFieldSpec(key: 'maxHumidity', label: 'أكبر رطوبة نسبية', kind: ObservationFieldKind.number, unit: '%'),
      const ObservationFieldSpec(key: 'maxHumidityTime', label: 'وقت أكبر رطوبة', kind: ObservationFieldKind.time),
      const ObservationFieldSpec(key: 'minHumidity', label: 'أصغر رطوبة نسبية', kind: ObservationFieldKind.number, unit: '%'),
      const ObservationFieldSpec(key: 'minHumidityTime', label: 'وقت أصغر رطوبة', kind: ObservationFieldKind.time),
    ],
    metadataFields: [
      const ObservationFieldSpec(key: 'observerNotes', label: 'ملاحظات الراصد', kind: ObservationFieldKind.multiline),
      _ack,
    ],
    sourceNotes: [
      'حقول الظواهر والتبخر والسطوع والرياح والرطوبة تظهر لتقرير 24h فقط في daily_fields_control.js.',
      'snowThickness remains required in HTML for all report types while explanatory text for 06utc/18utc says temperatures and precipitation only; unresolved.',
      'المطلوب النهائي لكل نوع تقرير لم يعتمد بعد.',
    ],
  ),
  ObservationModuleSpec(
    module: ObservationModule.agricultural,
    title: 'النشرة الزراعية',
    sourcePath: 'agricultural_reports.html',
    fields: [
      const ObservationFieldSpec(key: 'reportDate', label: 'تاريخ التقرير', kind: ObservationFieldKind.date),
      const ObservationFieldSpec(key: 'avgAirTemp', label: 'معدل درجة حرارة الهواء', kind: ObservationFieldKind.number, unit: '°س'),
      const ObservationFieldSpec(key: 'maxAirTemp', label: 'درجة حرارة الهواء العظمى', kind: ObservationFieldKind.number, unit: '°س'),
      const ObservationFieldSpec(key: 'minAirTemp', label: 'درجة حرارة الهواء الصغرى', kind: ObservationFieldKind.number, unit: '°س'),
      const ObservationFieldSpec(key: 'minTemp2m', label: 'درجة الحرارة الصغرى على ارتفاع مترين', kind: ObservationFieldKind.number, unit: '°س'),
      const ObservationFieldSpec(key: 'maxSoilSurfaceTemp', label: 'عظمى حرارة سطح التربة', kind: ObservationFieldKind.number, unit: '°س'),
      const ObservationFieldSpec(key: 'minSoilSurfaceTemp', label: 'صغرى حرارة سطح التربة', kind: ObservationFieldKind.number, unit: '°س'),
      const ObservationFieldSpec(key: 'avgHumidity', label: 'معدل الرطوبة النسبية', kind: ObservationFieldKind.number, unit: '%'),
      const ObservationFieldSpec(key: 'minHumidity', label: 'أدنى رطوبة نسبية', kind: ObservationFieldKind.number, unit: '%'),
      const ObservationFieldSpec(key: 'avgEsE', label: 'معدل ES-E', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'minEsE', label: 'أدنى ES-E', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'sunshineHours', label: 'مدة سطوع الشمس', kind: ObservationFieldKind.number, unit: 'ساعة'),
      const ObservationFieldSpec(key: 'totalCloudCover', label: 'معدل التغطية الكلية للغيوم', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'lowCloudCover', label: 'معدل تغطية الغيوم المنخفضة', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'precipitation', label: 'الهطول', kind: ObservationFieldKind.number, unit: 'مم'),
      const ObservationFieldSpec(key: 'maxWindSpeed', label: 'أكبر سرعة رياح من المخطط', kind: ObservationFieldKind.number, unit: 'م/ث'),
      const ObservationFieldSpec(key: 'classAEvaporation', label: 'تبخر حوض Class A', kind: ObservationFieldKind.number, unit: 'مم'),
      const ObservationFieldSpec(key: 'avgWindSpeed2m', label: 'معدل سرعة الرياح على ارتفاع مترين', kind: ObservationFieldKind.number, unit: 'م/ث'),
      ...[
        ['avgSoilTemp5cm', 'متوسط حرارة التربة على عمق 5 سم'],
        ['avgSoilTemp10cm', 'متوسط حرارة التربة على عمق 10 سم'],
        ['avgSoilTemp20cm', 'متوسط حرارة التربة على عمق 20 سم'],
        ['avgSoilTemp50cm', 'متوسط حرارة التربة على عمق 50 سم'],
        ['fieldSoilTemp5cm', 'حرارة تربة الحقل على عمق 5 سم'],
        ['fieldSoilTemp10cm', 'حرارة تربة الحقل على عمق 10 سم'],
      ].map((e) => ObservationFieldSpec(key: e[0], label: e[1], kind: ObservationFieldKind.number, unit: '°س')),
      const ObservationFieldSpec(key: 'logEvaporation', label: 'التبخر من السجل', kind: ObservationFieldKind.number, unit: 'مم'),
      ...[
        ['dew', 'ندى'], ['fog', 'ضباب'], ['hail', 'برد'], ['sandstorm', 'عواصف رملية أو ترابية'],
      ].map((e) => ObservationFieldSpec(key: e[0], label: e[1], kind: ObservationFieldKind.boolean)),
    ],
    metadataFields: [_notes, _ack],
    sourceNotes: ['قواعد required/range والمفقودات الزراعية لم تُستخلص بعد من جميع سكربتات التحقق؛ لا تُفعّل الإرسال حتى اعتمادها.'],
  ),
  const ObservationModuleSpec(
    module: ObservationModule.rainfall,
    title: 'النشرة المطرية',
    sourcePath: 'rainfall_reports.html',
    fields: [
      const ObservationFieldSpec(key: 'currentDate', label: 'تاريخ التقرير', kind: ObservationFieldKind.date),
      const ObservationFieldSpec(key: 'localTime', label: 'التوقيت المحلي', kind: ObservationFieldKind.time),
      const ObservationFieldSpec(key: 'utcTime', label: 'التوقيت العالمي UTC', kind: ObservationFieldKind.time),
      const ObservationFieldSpec(key: 'rainAmount', label: 'كمية الهطول المطري', kind: ObservationFieldKind.number, unit: 'مم'),
      const ObservationFieldSpec(key: 'snowDepth', label: 'سماكة الثلج', kind: ObservationFieldKind.number, unit: 'سم'),
      const ObservationFieldSpec(key: 'observationDate', label: 'تاريخ الرصد', kind: ObservationFieldKind.date),
    ],
    metadataFields: [_rainAck],
    sourceNotes: ['توقيت الإرسال وحدود الفترة الزمنية مذكورة في إقرار النموذج الأصلي؛ يلزم التحقق من قواعد UTC والتحويل قبل الإرسال.'],
  ),
  const ObservationModuleSpec(
    module: ObservationModule.weatherPhenomenon,
    title: 'بلاغ ظاهرة جوية',
    sourcePath: 'weather_phenomena.html',
    apiObservationType: 'phenomenon',
    submitSupportedByCurrentApi: true,
    fields: [
      const ObservationFieldSpec(key: 'phenomenonType', label: 'نوع الظاهرة الجوية', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'startTime', label: 'وقت بدء الظاهرة', kind: ObservationFieldKind.date),
      const ObservationFieldSpec(key: 'endTime', label: 'وقت انتهاء الظاهرة', kind: ObservationFieldKind.date),
    ],
    metadataFields: [
      const ObservationFieldSpec(key: 'notes', label: 'ملاحظات إضافية', kind: ObservationFieldKind.multiline),
    ],
    sourceNotes: ['قائمة أنواع الظواهر الدقيقة تؤخذ من خيارات select الأصلية وتحتاج مطابقة مع WeatherPhenomenonValidator قبل الإرسال.'],
  ),
  const ObservationModuleSpec(
    module: ObservationModule.agriculturalPhenomenon,
    title: 'الظواهر الزراعية',
    sourcePath: 'agricultural_reports.html',
    fields: [
      const ObservationFieldSpec(key: 'dew', label: 'ندى', kind: ObservationFieldKind.boolean),
      const ObservationFieldSpec(key: 'fog', label: 'ضباب', kind: ObservationFieldKind.boolean),
      const ObservationFieldSpec(key: 'hail', label: 'برد', kind: ObservationFieldKind.boolean),
      const ObservationFieldSpec(key: 'sandstorm', label: 'عواصف رملية أو ترابية', kind: ObservationFieldKind.boolean),
    ],
    metadataFields: [_notes, _ack],
  ),
  const ObservationModuleSpec(
    module: ObservationModule.soilTemperature,
    title: 'حرارة التربة',
    sourcePath: 'soil-send.html',
    fields: [
      const ObservationFieldSpec(key: 'utcTime', label: 'ساعة الرصد UTC', kind: ObservationFieldKind.time),
      const ObservationFieldSpec(key: 'soilTemp5cm', label: 'حرارة التربة على عمق 5 سم', kind: ObservationFieldKind.number, unit: '°س'),
      const ObservationFieldSpec(key: 'soilTemp10cm', label: 'حرارة التربة على عمق 10 سم', kind: ObservationFieldKind.number, unit: '°س'),
      const ObservationFieldSpec(key: 'soilTemp20cm', label: 'حرارة التربة على عمق 20 سم', kind: ObservationFieldKind.number, unit: '°س'),
      const ObservationFieldSpec(key: 'soilTemp50cm', label: 'حرارة التربة على عمق 50 سم', kind: ObservationFieldKind.number, unit: '°س'),
    ],
    metadataFields: [_notes, _soilAck],
    sourceNotes: ['soil-validation.js يسمح بالقيمة # لدرجة الحرارة ويحدد ساعات UTC: 23,02,05,08,11,14,17,20.'],
  ),
  const ObservationModuleSpec(
    module: ObservationModule.observationEquipmentFault,
    title: 'أعطال أجهزة الرصد',
    sourcePath: 'fix.html',
    fields: [
      const ObservationFieldSpec(key: 'failureDescription', label: 'وصف العطل', kind: ObservationFieldKind.multiline),
      const ObservationFieldSpec(key: 'failureDate', label: 'تاريخ ووقت حدوث العطل', kind: ObservationFieldKind.date),
      const ObservationFieldSpec(key: 'failureSeverity', label: 'شدة العطل', kind: ObservationFieldKind.choice, choices: ['منخفض', 'متوسط', 'مرتفع', 'حرج']),
      const ObservationFieldSpec(key: 'failureImage', label: 'صور العطل', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'urgentRepair', label: 'العطل عاجل ويحتاج إلى تدخل سريع', kind: ObservationFieldKind.boolean),
      const ObservationFieldSpec(key: 'manualMeasurementType', label: 'نوع المقياس', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'manualMeasurementProblem', label: 'نوع مشكلة المقياس', kind: ObservationFieldKind.choice, choices: ['كسر في الجهاز', 'تلف في الأجزاء', 'عدم دقة في القياس', 'عدم استجابة الجهاز', 'تآكل الأجزاء', 'مشكلة أخرى']),
      const ObservationFieldSpec(key: 'manualMeasurementDescription', label: 'وصف عطل المقياس', kind: ObservationFieldKind.multiline),
      const ObservationFieldSpec(key: 'manualMeasurementDate', label: 'تاريخ ووقت عطل المقياس', kind: ObservationFieldKind.date),
      const ObservationFieldSpec(key: 'manualMeasurementSeverity', label: 'شدة عطل المقياس', kind: ObservationFieldKind.choice, choices: ['منخفض', 'متوسط', 'مرتفع', 'حرج']),
      const ObservationFieldSpec(key: 'manualMeasurementImage', label: 'صورة العطل', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'manualMeasurementUrgent', label: 'عطل المقياس عاجل', kind: ObservationFieldKind.boolean),
    ],
    metadataFields: [
      const ObservationFieldSpec(key: 'includeDetails', label: 'تضمين تفاصيل العطل', kind: ObservationFieldKind.boolean),
      const ObservationFieldSpec(key: 'includeContact', label: 'تضمين معلومات الاتصال', kind: ObservationFieldKind.boolean),
      const ObservationFieldSpec(key: 'includeStatus', label: 'تضمين حالة البلاغ', kind: ObservationFieldKind.boolean),
    ],
    sourceNotes: ['حقول الصور تحتاج مسار رفع آمن مستقل؛ لا تحفظ صوراً كقيمة نصية ولا ترفعها قبل تصميم Storage وصلاحياته.'],
  ),
  const ObservationModuleSpec(
    module: ObservationModule.telecommunicationsFault,
    title: 'أعطال الاتصالات',
    sourcePath: 'fix-tel.html',
    fields: [
      const ObservationFieldSpec(key: 'phoneType', label: 'نوع الهاتف', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'phoneBrand', label: 'ماركة الهاتف', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'problemType', label: 'نوع المشكلة', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'description', label: 'وصف المشكلة', kind: ObservationFieldKind.multiline),
      const ObservationFieldSpec(key: 'urgent', label: 'بلاغ عاجل', kind: ObservationFieldKind.boolean),
      const ObservationFieldSpec(key: 'towerType', label: 'نوع البرج', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'towerHeight', label: 'ارتفاع البرج', kind: ObservationFieldKind.number),
      const ObservationFieldSpec(key: 'satelliteType', label: 'نوع جهاز الأقمار الصناعية', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'satelliteBrand', label: 'ماركة جهاز الأقمار الصناعية', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'faxType', label: 'نوع جهاز الفاكس', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'faxBrand', label: 'ماركة الفاكس', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'computerType', label: 'نوع الحاسوب', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'computerBrand', label: 'ماركة الحاسوب', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'laptopType', label: 'نوع الحاسوب المحمول', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'laptopBrand', label: 'ماركة الحاسوب المحمول', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'printerType', label: 'نوع الطابعة', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'printerBrand', label: 'ماركة الطابعة', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'networkType', label: 'نوع الشبكة', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'networkBrand', label: 'اسم/ماركة الشبكة', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'wifiType', label: 'نوع شبكة Wi-Fi', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'wifiBrand', label: 'اسم/ماركة Wi-Fi', kind: ObservationFieldKind.text),
    ],
    metadataFields: [_notes],
    sourceNotes: ['تُعرض حقول الجهاز المناسبة فقط وفق نوع جهاز الاتصال المختار؛ يلزم استخراج شروط الظهور من سكربتات الصفحة قبل التحقق.'],
  ),
  ObservationModuleSpec(
    module: ObservationModule.itIncident,
    title: 'بلاغات أعطال تقنية المعلومات',
    sourcePath: 'it.html',
    fields: [
      const ObservationFieldSpec(key: 'reporterName', label: 'اسم مقدم البلاغ', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'reporterPosition', label: 'الصفة الوظيفية', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'reporterPhone', label: 'رقم الهاتف', kind: ObservationFieldKind.text),
      const ObservationFieldSpec(key: 'bulletinType', label: 'نوع النشرة المتأثرة', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'problemField', label: 'الحقل الذي به المشكلة', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'problemType', label: 'نوع المشكلة', kind: ObservationFieldKind.choice),
      const ObservationFieldSpec(key: 'problemDescription', label: 'وصف المشكلة', kind: ObservationFieldKind.multiline),
      const ObservationFieldSpec(key: 'problemUrgency', label: 'درجة الأهمية', kind: ObservationFieldKind.choice, choices: ['منخفضة', 'متوسطة', 'عالية', 'حرجة']),
      ...[
        ['fieldName', 'اسم الحقل الحالي'], ['suggestedName', 'الاسم المقترح للحقل'],
        ['currentValue', 'القيمة الحالية'], ['expectedValue', 'القيمة المتوقعة'],
        ['currentUnit', 'الوحدة الحالية'], ['correctUnit', 'الوحدة الصحيحة'],
        ['currentMask', 'قناع الإدخال الحالي'], ['suggestedMask', 'قناع الإدخال المقترح'],
        ['fieldConditions', 'شروط الحقل الحالية'], ['conditionIssue', 'مشكلة شروط الحقل'],
        ['extraFieldName', 'اسم الحقل الزائد'], ['whyExtra', 'سبب اعتبار الحقل زائداً'],
        ['missingFieldName', 'اسم الحقل الناقص'], ['fieldImportance', 'أهمية الحقل الناقص'],
        ['extraDetails', 'تفاصيل إضافية'],
      ].map((e) => ObservationFieldSpec(key: e[0], label: e[1], kind: ObservationFieldKind.text)),
    ],
    metadataFields: [],
    sourceNotes: ['الحقول التفصيلية تتغير حسب problemType؛ أسماء الحقول الشرطية مصدرها نموذج IT الأصلي ويجب ربطها بنوع المشكلة قبل التحقق.'],
  ),
];

ObservationModuleSpec observationModuleSpec(ObservationModule module) =>
    observationModuleCatalogue.firstWhere((spec) => spec.module == module);
