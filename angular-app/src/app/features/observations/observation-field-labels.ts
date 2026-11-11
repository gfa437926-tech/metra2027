/** Arabic labels and light client-side checks for observation payload editors. */

export const OBSERVATION_FIELD_LABELS: Record<string, string> = {
  dry_bulb_c: 'الحرارة الجافة (°م)',
  wet_bulb_c: 'الحرارة الرطبة (°م)',
  dryTemp: 'الحرارة الجافة (°م)',
  wetTemp: 'الحرارة الرطبة (°م)',
  relative_humidity_pct: 'الرطوبة النسبية (%)',
  humidity: 'الرطوبة النسبية (%)',
  wind_speed_ms: 'سرعة الرياح (م/ث)',
  windSpeed: 'سرعة الرياح (م/ث)',
  wind_direction_deg: 'اتجاه الرياح (°)',
  windDirection: 'اتجاه الرياح (°)',
  pressure_hpa: 'الضغط الجوي (هكتوباسكال)',
  pressure: 'الضغط الجوي (هكتوباسكال)',
  visibility_m: 'الرؤية (م)',
  visibility: 'الرؤية (م)',
  cloud_cover_oktas: 'الغطاء السحابي (أوكتا)',
  cloudCover: 'الغطاء السحابي (أوكتا)',
  cloudType: 'نوع السحب',
  cloudBase: 'قاعدة السحب',
  phenomenonCode: 'رمز الظاهرة',
  phenomenonText: 'وصف الظاهرة',
  intensity: 'الشدة',
  startTime: 'وقت البداية',
  endTime: 'وقت النهاية',
  rainfall_mm: 'الهطول (مم)',
  soil_temp_c: 'حرارة التربة (°م)',
};

export interface EditableObservationField {
  key: string;
  label: string;
  value: string;
  /** True when review note appears to reference this field. */
  highlighted: boolean;
  hint: string;
  error: string;
}

export function buildEditableFields(
  payload: Record<string, unknown> | null | undefined,
  reviewNote?: string | null
): EditableObservationField[] {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return [];
  }
  const note = (reviewNote ?? '').toLowerCase();
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
      const label = OBSERVATION_FIELD_LABELS[key] ?? key;
      const highlighted =
        note.length > 0 &&
        (note.includes(key.toLowerCase()) ||
          note.includes(label.toLowerCase()) ||
          // common Arabic cues without exact key match still flag temperature/humidity groups
          (/(حرارة|رطب|جاف)/.test(note) && /temp|bulb|حرارة/.test(key + label)) ||
          (/(رياح|اتجاه|سرعة)/.test(note) && /wind|رياح/.test(key + label)) ||
          (/(ضغط)/.test(note) && /pressure|ضغط/.test(key + label)) ||
          (/(رطوب)/.test(note) && /humid|رطوب/.test(key + label)));
      return {
        key,
        label,
        value,
        highlighted,
        hint: highlighted ? 'يُرجى مراجعة هذا الحقل وفق ملاحظة المراجع.' : '',
        error: '',
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

/** Returns Arabic validation errors keyed by field key. Empty map means OK. */
export function validateEditableFields(
  fields: EditableObservationField[]
): Record<string, string> {
  const errors: Record<string, string> = {};
  const num = (key: string): number | null => {
    const f = fields.find((x) => x.key === key);
    if (!f || f.value.trim() === '') return null;
    const n = Number(f.value.replace(',', '.'));
    return Number.isFinite(n) ? n : NaN;
  };

  const checkRange = (keys: string[], min: number, max: number, label: string) => {
    for (const key of keys) {
      const v = num(key);
      if (v === null) continue;
      if (Number.isNaN(v) || v < min || v > max) {
        errors[key] = `${label} يجب أن تكون بين ${min} و ${max}.`;
      }
    }
  };

  checkRange(['dry_bulb_c', 'dryTemp'], -50, 60, 'الحرارة الجافة');
  checkRange(['wet_bulb_c', 'wetTemp'], -50, 50, 'الحرارة الرطبة');
  checkRange(['relative_humidity_pct', 'humidity'], 0, 100, 'الرطوبة النسبية');
  checkRange(['wind_speed_ms', 'windSpeed'], 0, 150, 'سرعة الرياح');
  checkRange(['wind_direction_deg', 'windDirection'], 0, 360, 'اتجاه الرياح');
  checkRange(['pressure_hpa', 'pressure'], 870, 1080, 'الضغط الجوي');
  checkRange(['visibility_m', 'visibility'], 0, 100000, 'الرؤية');
  checkRange(['cloud_cover_oktas', 'cloudCover'], 0, 8, 'الغطاء السحابي');

  const dry = num('dry_bulb_c') ?? num('dryTemp');
  const wet = num('wet_bulb_c') ?? num('wetTemp');
  if (dry !== null && wet !== null && !Number.isNaN(dry) && !Number.isNaN(wet) && wet > dry) {
    for (const key of ['wet_bulb_c', 'wetTemp']) {
      if (fields.some((f) => f.key === key)) {
        errors[key] = 'الحرارة الرطبة يجب ألا تتجاوز الحرارة الجافة.';
      }
    }
  }

  return errors;
}
