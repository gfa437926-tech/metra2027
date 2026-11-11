'use strict';

const RULES = {
  minTemp: [/^-?\d{2}\.\d$/, -20, 50],
  maxTemp: [/^-?\d{2}\.\d$/, -20, 50],
  precipitation: [/^\d{3}\.\d$/, 0, 999.9],
  snowThickness: [/^\d{3}$/, 0, 999],
  evaporation: [/^\d{2}\.\d$/, 0, 99.9],
  sunshineDuration: [/^\d{2}\.\d$/, 0, 24],
  sunshinePercentage: [/^\d{3}$/, 0, 100],
  maxGustSpeed: [/^\d{2}$/, 0, 36],
  maxGustDirection: [/^\d{2}$/, 0, 36],
  maxGustTime: [/^\d{2}\.\d$/, 0, 23.9],
  maxHumidity: [/^\d{3}$/, 0, 100],
  minHumidity: [/^\d{2}$/, 0, 99],
  maxHumidityTime: [/^\d{2}\.\d$/, 0, 23.9],
  minHumidityTime: [/^\d{2}\.\d$/, 0, 23.9]
};
// snowThickness stays in RULES for format checks when provided, but is not
// universally required — station observing programs differ (pending policy).
const FULL_DAY = Object.keys(RULES).filter((key) => key !== 'snowThickness');
const SYNOPTIC = ['minTemp', 'maxTemp', 'precipitation'];

function validateDailyObservation(reportType, values, responsibilityAgreement) {
  const errors = {};
  // UI accepts 24h daily summary only; 06/18 UTC belong to hourly workflow.
  const required = reportType === '24h' ? FULL_DAY :
    (reportType === '06utc' || reportType === '18utc') ? SYNOPTIC : null;
  if (!required) {
    errors.reportType = 'Unsupported daily report type.';
    return errors;
  }
  if (responsibilityAgreement !== true) errors.responsibilityAgreement = 'Responsibility agreement is required.';
  for (const key of required) {
    const value = String(values[key] ?? '').trim();
    if (!value) errors[key] = 'Required for this report type.';
  }
  for (const [key, [pattern, min, max]] of Object.entries(RULES)) {
    const value = String(values[key] ?? '').trim();
    if (!value || value === '#') continue;
    const number = Number(value);
    if (!pattern.test(value) || !Number.isFinite(number) || number < min || number > max) {
      errors[key] = 'Value format or range is invalid.';
    }
  }
  const trace = String(values.precipitationTrace ?? '').trim();
  if (trace && trace !== '#' && !/^[Tt]$/.test(trace)) {
    errors.precipitationTrace = 'Precipitation trace must be T or t.';
  }
  const minTemp = String(values.minTemp ?? '').trim();
  const maxTemp = String(values.maxTemp ?? '').trim();
  if (minTemp && maxTemp && minTemp !== '#' && maxTemp !== '#' && Number(maxTemp) < Number(minTemp)) {
    errors.maxTemp = 'Maximum temperature must not be below minimum temperature.';
  }
  const maxHumidity = String(values.maxHumidity ?? '').trim();
  const minHumidity = String(values.minHumidity ?? '').trim();
  if (maxHumidity && minHumidity && maxHumidity !== '#' && minHumidity !== '#' && Number(minHumidity) > Number(maxHumidity)) {
    errors.minHumidity = 'Minimum humidity must not exceed maximum humidity.';
  }
  return errors;
}

module.exports = { validateDailyObservation };
