'use strict';

/** Executable mirror of the canonical METRA hourly observation v1 rules. */
const ALWAYS_REQUIRED = [
  'dryTemp', 'wetTemp', 'stationPressure', 'seaLevelPressure', 'windDirection',
  'windSpeed', 'visibility', 'totalCloudCover', 'relativeHumidity', 'dewPoint',
  'cover12', 'cover123'
];
const SYNOPTIC_HOURS = new Set([0, 3, 6, 9, 12, 15, 18, 21]);
const PRECIPITATION_HOURS = new Set([0, 6, 12, 18]);
const RULES = {
  dryTemp: [/^[+-]\\d{2}\\.\\d$/, -20, 50],
  wetTemp: [/^[+-]\\d{2}\\.\\d$/, -20, 50],
  dewPoint: [/^[+-]\\d{2}\\.\\d$/, -20, 50],
  stationPressure: [/^\\d{4}\\.\\d$/, 850, 1050],
  seaLevelPressure: [/^\\d{4}\\.\\d$/, 0, 1050],
  relativeHumidity: [/^\\d{3}$/, 1, 100],
  vaporPressure: [/^\\d{2}\\.\\d$/, 0, 99],
  vaporPressureDiff: [/^\\d{2}\\.\\d$/, 0, 99],
  windDirection: [/^\\d{2}$/, 0, 36],
  avgWindDirection: [/^\\d{2}$/, 0, 36],
  windSpeed: [/^\\d{2}$/, 0, 99],
  avgWindSpeed: [/^\\d{2}$/, 0, 99],
  visibility: [/^\\d{3}$/, 0, 200],
  currentWeather: [/^\\d{2}$/, 0, 99],
  pastWeather: [/^\\d$/, 0, 9],
  totalCloudCover: [/^\\d$/, 0, 8],
  cloud1Amount: [/^[0-8]$/, 0, 8],
  cloud2Amount: [/^[0-8]$/, 0, 8],
  cloud3Amount: [/^[0-8]$/, 0, 8],
  cloud4Amount: [/^[0-8]$/, 0, 8],
  cloud1Height: [/^\\d{1,3}$/, 0, 999],
  cloud2Height: [/^\\d{1,3}$/, 0, 999],
  cloud3Height: [/^\\d{1,3}$/, 0, 999],
  cover12: [/^[0-8]$/, 0, 8],
  cover123: [/^[0-8]$/, 0, 8],
  pressureSlope: [/^\\d{1,2}\\.\\d$/, 0, 99],
  pressureShape: [/^[0-8]$/, 0, 8],
  precipitationAmount: [/^\\d{3}\\.\\d$/, 0, 999.9]
};

function validateHourlyObservation(values) {
  const errors = {};
  const utcTime = String(values.utcTime ?? '').trim();
  if (!/^\\d{2}$/.test(utcTime) || Number(utcTime) < 0 || Number(utcTime) > 23) {
    errors.utcTime = 'UTC hour must be two digits from 00 to 23.';
    return errors;
  }
  const hour = Number(utcTime);
  const required = [...ALWAYS_REQUIRED];
  if (PRECIPITATION_HOURS.has(hour)) required.push('precipitationAmount');
  if (SYNOPTIC_HOURS.has(hour)) required.push('pressureSlope', 'pressureShape', 'pastWeather');
  for (const key of required) {
    if (!String(values[key] ?? '').trim()) errors[key] = 'Required for the selected UTC hour.';
  }
  for (const [key, [pattern, min, max]] of Object.entries(RULES)) {
    const value = String(values[key] ?? '').trim();
    if (!value || value === '#') continue;
    const numeric = Number(value);
    if (!pattern.test(value) || !Number.isFinite(numeric) || numeric < min || numeric > max) {
      errors[key] = 'Value format or range is invalid.';
    }
  }
  const dry = String(values.dryTemp ?? '').trim();
  const wet = String(values.wetTemp ?? '').trim();
  if (dry && wet && dry !== '#' && wet !== '#' && Number(dry) < Number(wet)) {
    errors.dryTemp = 'Dry temperature must be greater than or equal to wet temperature.';
  }
  return errors;
}

module.exports = { validateHourlyObservation };
