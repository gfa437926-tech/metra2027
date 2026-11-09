import 'package:flutter/material.dart';

/// Arabic labels for known observation payload keys.
const Map<String, String> observationFieldLabels = {
  'minTemp': 'درجة الحرارة الصغرى',
  'precipitationTrace': 'الهطول الأثري',
  'snowThickness': 'سماكة الثلج',
  'maxTemp': 'درجة الحرارة العظمى',
  'precipitation': 'الهطول',
  'snowThickness': 'سماكة الثلج',
  'evaporation': 'التبخر',
  'sunshineDuration': 'مدة سطوع الشمس',
  'sunshinePercentage': 'نسبة سطوع الشمس',
  'maxGustSpeed': 'سرعة هبات الرياح',
  'maxGustDirection': 'اتجاه هبات الرياح',
  'maxGustTime': 'وقت هبة الرياح العظمى',
  'maxHumidityTime': 'وقت الرطوبة العظمى',
  'minHumidityTime': 'وقت الرطوبة الصغرى',
  'maxHumidity': 'الرطوبة العظمى',
  'minHumidity': 'الرطوبة الصغرى',
  'dryTemp': 'الحرارة الجافة',
  'wetTemp': 'الحرارة الرطبة',
  'dewPoint': 'نقطة الندى',
  'stationPressure': 'الضغط الجوي بالمحطة',
  'seaLevelPressure': 'الضغط المصحح لمستوى سطح البحر',
  'relativeHumidity': 'الرطوبة النسبية',
  'vaporPressure': 'ضغط البخار',
  'vaporPressureDiff': 'فرق ضغط البخار',
  'windDirection': 'اتجاه الرياح',
  'avgWindDirection': 'متوسط اتجاه الرياح',
  'windSpeed': 'سرعة الرياح',
  'avgWindSpeed': 'متوسط سرعة الرياح',
  'visibility': 'مدى الرؤية',
  'currentWeather': 'الطقس الحالي',
  'pastWeather': 'الطقس السابق',
  'totalCloudCover': 'الغيوم الكلية',
  'lowCloudCover': 'الغيوم المنخفضة',
  'cloudType': 'نوع السحب',
  'cloudBase': 'قاعدة السحب',
  'phenomenonCode': 'رمز الظاهرة',
  'phenomenonText': 'وصف الظاهرة',
  'intensity': 'الشدة',
  'startTime': 'وقت البداية',
  'endTime': 'وقت النهاية',
};

class EditableObservationField {
  EditableObservationField({
    required this.key,
    required this.label,
    required this.controller,
  });

  final String key;
  final String label;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

List<EditableObservationField> buildEditableFields(
  Map<String, dynamic> payload,
) {
  final keys = payload.keys.toList()..sort();
  return [
    for (final key in keys)
      EditableObservationField(
        key: key,
        label: observationFieldLabels[key] ?? key,
        controller: TextEditingController(
          text: payload[key] == null ? '' : '${payload[key]}',
        ),
      ),
  ];
}

Map<String, String> fieldsToPayload(List<EditableObservationField> fields) {
  return {
    for (final field in fields) field.key: field.controller.text.trim(),
  };
}
