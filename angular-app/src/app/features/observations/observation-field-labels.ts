/** Arabic labels for known observation payload keys (daily / hourly / phenomenon). */
export const OBSERVATION_FIELD_LABELS: Record<string, string> = {
  minTemp: 'درجة الحرارة الصغرى',
  maxTemp: 'درجة الحرارة العظمى',
  precipitation: 'الهطول',
  snowThickness: 'سماكة الثلج',
  evaporation: 'التبخر',
  sunshineDuration: 'مدة سطوع الشمس',
  sunshinePercentage: 'نسبة سطوع الشمس',
  maxGustSpeed: 'سرعة هبات الرياح',
  maxGustDirection: 'اتجاه هبات الرياح',
  maxGustTime: 'وقت هبة الرياح العظمى',
  maxHumidityTime: 'وقت الرطوبة العظمى',
  minHumidityTime: 'وقت الرطوبة الصغرى',
  maxHumidity: 'الرطوبة العظمى',
  minHumidity: 'الرطوبة الصغرى',
  dryTemp: 'الحرارة الجافة',
  wetTemp: 'الحرارة الرطبة',
  dewPoint: 'نقطة الندى',
  stationPressure: 'الضغط الجوي بالمحطة',
  seaLevelPressure: 'الضغط المصحح لمستوى سطح البحر',
  relativeHumidity: 'الرطوبة النسبية',
  vaporPressure: 'ضغط البخار',
  vaporPressureDiff: 'فرق ضغط البخار',
  windDirection: 'اتجاه الرياح',
  avgWindDirection: 'متوسط اتجاه الرياح',
  windSpeed: 'سرعة الرياح',
  avgWindSpeed: 'متوسط سرعة الرياح',
  visibility: 'مدى الرؤية',
  currentWeather: 'الطقس الحالي',
  pastWeather: 'الطقس السابق',
  totalCloudCover: 'الغيوم الكلية',
  lowCloudCover: 'الغيوم المنخفضة',
  cloudType: 'نوع السحب',
  cloudBase: 'قاعدة السحب',
  phenomenonCode: 'رمز الظاهرة',
  phenomenonText: 'وصف الظاهرة',
  intensity: 'الشدة',
  startTime: 'وقت البداية',
  endTime: 'وقت النهاية',
};

export interface EditableObservationField {
  key: string;
  label: string;
  value: string;
}

export function buildEditableFields(
  payload: Record<string, unknown> | null | undefined
): EditableObservationField[] {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return [];
  }
  return Object.keys(payload)
    .sort((a, b) => a.localeCompare(b))
    .map((key) => {
      const raw = payload[key];
      const value =
        raw === null || raw === undefined
          ? ''
          : typeof raw === 'string' || typeof raw === 'number' || typeof raw === 'boolean'
            ? String(raw)
            : JSON.stringify(raw);
      return {
        key,
        label: OBSERVATION_FIELD_LABELS[key] ?? key,
        value,
      };
    });
}

export function fieldsToPayload(
  fields: EditableObservationField[]
): Record<string, string> {
  const payload: Record<string, string> = {};
  for (const field of fields) {
    payload[field.key] = field.value.trim();
  }
  return payload;
}
