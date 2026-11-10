const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { validateHourlyObservation } = require('../src/app/features/observations/hourly-observation-contract.cjs');
const { validateDailyObservation } = require('../src/app/features/observations/daily-observation-contract.cjs');

const fixturesDir = path.resolve(__dirname, '../../contracts/observation-v1/fixtures');
const manifest = JSON.parse(fs.readFileSync(path.join(fixturesDir, 'manifest.json'), 'utf8'));

test('shared observation fixture manifest is complete and has unique cases', () => {
  assert.equal(manifest.contractVersion, '1.0');
  assert.ok(Array.isArray(manifest.fixtures) && manifest.fixtures.length >= 8);
  assert.equal(new Set(manifest.fixtures).size, manifest.fixtures.length);
  const ids = new Set();
  for (const name of manifest.fixtures) {
    const fixture = JSON.parse(fs.readFileSync(path.join(fixturesDir, name), 'utf8'));
    assert.ok(fixture.id, name + ' must declare an id');
    assert.ok(!ids.has(fixture.id), 'duplicate fixture id: ' + fixture.id);
    ids.add(fixture.id);
    assert.equal(typeof fixture.expectValid, 'boolean', fixture.id);
    assert.ok(fixture.values && typeof fixture.values === 'object', fixture.id);
    assert.ok(Array.isArray(fixture.expectErrorFields), fixture.id);
  }
});

test('valid daily fixtures contain the canonical required fields for each report type', () => {
  const required = {
    '24h': ['minTemp', 'maxTemp', 'precipitation', 'evaporation',
      'sunshineDuration', 'sunshinePercentage', 'maxGustSpeed', 'maxGustDirection',
      'maxGustTime', 'maxHumidity', 'maxHumidityTime', 'minHumidity', 'minHumidityTime'],
    '06utc': ['minTemp', 'maxTemp', 'precipitation'],
    '18utc': ['minTemp', 'maxTemp', 'precipitation']
  };
  const seen = new Set();
  for (const name of manifest.fixtures) {
    const fixture = JSON.parse(fs.readFileSync(path.join(fixturesDir, name), 'utf8'));
    if (fixture.observationType !== 'daily' || !fixture.expectValid) continue;
    assert.equal(fixture.responsibilityAgreement, true, fixture.id);
    assert.ok(required[fixture.reportType], 'unsupported report type in ' + fixture.id);
    for (const field of required[fixture.reportType]) {
      assert.ok(Object.hasOwn(fixture.values, field), fixture.id + ' missing ' + field);
    }
    seen.add(fixture.reportType);
  }
  assert.deepEqual([...seen].sort(), ['06utc', '18utc', '24h']);
});

test('hourly valid fixture includes every always-required canonical field', () => {
  const fixture = manifest.fixtures
    .map(name => JSON.parse(fs.readFileSync(path.join(fixturesDir, name), 'utf8')))
    .find(item => item.id === 'hourly-valid-synoptic');
  assert.ok(fixture);
  assert.equal(fixture.observationType, 'hourly');
  const required = ['utcTime', 'dryTemp', 'wetTemp', 'dewPoint', 'stationPressure',
    'seaLevelPressure', 'relativeHumidity', 'windDirection', 'windSpeed', 'visibility',
    'totalCloudCover', 'cover12', 'cover123'];
  for (const field of required) assert.ok(Object.hasOwn(fixture.values, field), 'missing ' + field);
});

test('invalid shared fixtures declare the fields expected to fail', () => {
  const invalid = manifest.fixtures
    .map(name => JSON.parse(fs.readFileSync(path.join(fixturesDir, name), 'utf8')))
    .filter(item => !item.expectValid);
  assert.ok(invalid.length >= 2);
  for (const fixture of invalid) {
    assert.ok(fixture.expectErrorFields.length > 0, fixture.id + ' must identify expected error fields');
  }
});

test('hourly optional field fixture names stay aligned with the documented contract', () => {
  const contract = fs.readFileSync(path.resolve(__dirname, '../../docs/contracts/OBSERVATION-FIELD-CONTRACT-V1.md'), 'utf8');
  for (const field of ['vaporPressure', 'vaporPressureDiff', 'avgWindDirection', 'avgWindSpeed',
    'currentWeather', 'cloud1Amount', 'cloud4Amount', 'cloud1Type', 'cloud3Type',
    'cloud1Height', 'cloud3Height']) {
    assert.ok(contract.includes(field), 'contract missing optional field/range endpoint ' + field);
  }
  assert.match(contract, /cloud1Amount.{0,20}cloud4Amount/);
  assert.match(contract, /cloud1Type.{0,20}cloud3Type/);
  assert.match(contract, /cloud1Height.{0,20}cloud3Height/);
});

test('shared daily fixtures execute against Angular daily validation rules', () => {
  const daily = manifest.fixtures
    .map(name => JSON.parse(fs.readFileSync(path.join(fixturesDir, name), 'utf8')))
    .filter(fixture => fixture.observationType === 'daily');
  assert.equal(daily.length, 6);
  for (const fixture of daily) {
    const errors = validateDailyObservation(
      fixture.reportType,
      fixture.values,
      fixture.responsibilityAgreement === true
    );
    if (fixture.expectValid) {
      assert.deepEqual(errors, {}, fixture.id + ': ' + JSON.stringify(errors));
    } else {
      assert.ok(Object.keys(errors).length > 0, fixture.id + ' should be rejected');
      for (const field of fixture.expectErrorFields) {
        assert.ok(Object.hasOwn(errors, field), fixture.id + ' should report ' + field);
      }
    }
  }
});

test('shared hourly fixtures execute against Angular hourly validation rules', () => {
  const hourly = manifest.fixtures
    .map(name => JSON.parse(fs.readFileSync(path.join(fixturesDir, name), 'utf8')))
    .filter(fixture => fixture.observationType === 'hourly');
  assert.equal(hourly.length, 2);
  for (const fixture of hourly) {
    const errors = validateHourlyObservation(fixture.values);
    if (fixture.expectValid) {
      assert.deepEqual(errors, {}, fixture.id + ': ' + JSON.stringify(errors));
    } else {
      assert.ok(Object.keys(errors).length > 0, fixture.id + ' should be rejected');
      for (const field of fixture.expectErrorFields) {
        assert.ok(Object.hasOwn(errors, field), fixture.id + ' should report ' + field);
      }
    }
  }
});

test('all 24 UTC hours enforce the exact conditional field matrix', () => {
  const synopticHours = new Set([0, 3, 6, 9, 12, 15, 18, 21]);
  const precipitationHours = new Set([0, 6, 12, 18]);
  const base = JSON.parse(fs.readFileSync(path.join(fixturesDir, 'hourly-valid-synoptic.json'), 'utf8')).values;
  for (let hour = 0; hour < 24; hour++) {
    const utcTime = String(hour).padStart(2, '0');
    const values = { ...base, utcTime };
    if (!synopticHours.has(hour)) {
      delete values.pressureSlope;
      delete values.pressureShape;
      delete values.pastWeather;
    }
    if (!precipitationHours.has(hour)) delete values.precipitationAmount;
    assert.deepEqual(validateHourlyObservation(values), {}, utcTime + ' UTC should be valid');

    const required = [
      ...(synopticHours.has(hour) ? ['pressureSlope', 'pressureShape', 'pastWeather'] : []),
      ...(precipitationHours.has(hour) ? ['precipitationAmount'] : [])
    ];
    for (const field of required) {
      const missing = { ...values };
      delete missing[field];
      assert.ok(Object.hasOwn(validateHourlyObservation(missing), field),
        field + ' must be required at ' + utcTime + ' UTC');
    }
    const optional = [
      ...(!synopticHours.has(hour) ? ['pressureSlope', 'pressureShape', 'pastWeather'] : []),
      ...(!precipitationHours.has(hour) ? ['precipitationAmount'] : [])
    ];
    for (const field of optional) {
      const missing = { ...values };
      delete missing[field];
      assert.ok(!Object.hasOwn(validateHourlyObservation(missing), field),
        field + ' must remain optional at ' + utcTime + ' UTC');
    }
  }
});

test('hourly conditional requirements and cross-field checks execute', () => {
  const valid = JSON.parse(fs.readFileSync(path.join(fixturesDir, 'hourly-valid-synoptic.json'), 'utf8')).values;
  const missing = { ...valid, utcTime: '01' };
  delete missing.precipitationAmount;
  delete missing.pressureSlope;
  delete missing.pressureShape;
  delete missing.pastWeather;
  assert.deepEqual(validateHourlyObservation(missing), {});
  const synoptic = { ...valid, utcTime: '00' };
  delete synoptic.precipitationAmount;
  assert.ok(Object.hasOwn(validateHourlyObservation(synoptic), 'precipitationAmount'));
  const badTemperature = { ...valid, dryTemp: '+10.0', wetTemp: '+15.0' };
  assert.ok(Object.hasOwn(validateHourlyObservation(badTemperature), 'dryTemp'));
});
