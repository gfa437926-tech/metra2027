const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

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
    '24h': ['minTemp', 'maxTemp', 'precipitation', 'snowThickness', 'evaporation',
      'sunshineDuration', 'sunshinePercentage', 'maxGustSpeed', 'maxGustDirection',
      'maxGustTime', 'maxHumidity', 'maxHumidityTime', 'minHumidity', 'minHumidityTime'],
    '06utc': ['minTemp', 'maxTemp', 'precipitation', 'snowThickness'],
    '18utc': ['minTemp', 'maxTemp', 'precipitation', 'snowThickness']
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
    'currentWeather', 'cloud1Amount', 'cloud2Amount', 'cloud3Amount', 'cloud4Amount',
    'cloud1Type', 'cloud2Type', 'cloud3Type', 'cloud1Height', 'cloud2Height', 'cloud3Height']) {
    assert.ok(contract.includes(field), 'contract missing optional field ' + field);
  }
});
