const test = require('node:test');
const assert = require('node:assert/strict');
const {
  createIdempotencyKey,
  getOrCreateDailySubmissionKey,
  getConfirmedDailySubmission,
  getSubmissionErrorMessage,
  dailyObservedAtForReport
} = require('../.test-dist/daily-submission.utils.js');

test('uses native randomUUID when the secure API provides it', () => {
  const expected = '123e4567-e89b-42d3-a456-426614174000';
  const key = createIdempotencyKey({
    randomUUID: () => expected,
    getRandomValues: () => { throw new Error('fallback should not run'); }
  });
  assert.equal(key, expected);
});

test('creates an RFC 4122 UUID v4 using secure random bytes as fallback', () => {
  const key = createIdempotencyKey({
    getRandomValues: bytes => {
      bytes.fill(0);
      return bytes;
    }
  });
  assert.match(key, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-8[0-9a-f]{3}-[0-9a-f]{12}$/i);
});

test('fails closed when no cryptographically secure random source exists', () => {
  assert.throws(() => createIdempotencyKey({}), /مولّداً عشوائياً آمناً/);
});

test('accepts only a submitted receipt containing a UUID v4', () => {
  const id = '123e4567-e89b-42d3-a456-426614174000';
  assert.deepEqual(getConfirmedDailySubmission({ id, status: 'submitted', replayed: true }), {
    id, status: 'submitted', replayed: true
  });
  assert.equal(getConfirmedDailySubmission({ id, status: 'draft' }), null);
  assert.equal(getConfirmedDailySubmission({ id: 'not-a-uuid', status: 'submitted' }), null);
  assert.equal(getConfirmedDailySubmission({ status: 'submitted' }), null);
  assert.deepEqual(getConfirmedDailySubmission({ id, status: 'submitted', replayed: 'yes' }), {
    id, status: 'submitted'
  });
  assert.equal(getConfirmedDailySubmission({ id, status: 'submitted' }).replayed, undefined);
  assert.equal(getConfirmedDailySubmission(null), null);
});

test('maps daily report types to their current UTC timestamps', () => {
  assert.equal(dailyObservedAtForReport('2026-11-08', '24h'), '2026-11-08T00:00:00.000Z');
  assert.equal(dailyObservedAtForReport('2026-11-08', '06utc'), '2026-11-08T06:00:00.000Z');
  assert.equal(dailyObservedAtForReport('2026-11-08', '18utc'), '2026-11-08T18:00:00.000Z');
  assert.throws(() => dailyObservedAtForReport('not-a-date', '24h'), RangeError);
});

test('persists only a hashed fingerprint and reuses the key after reload', async () => {
  const { webcrypto } = require('node:crypto');
  const values = new Map();
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) };
  const fingerprint = JSON.stringify({ stationId: 'station-1', report: { minTemp: '-05.3' } });
  const first = await getOrCreateDailySubmissionKey(fingerprint, null, storage, webcrypto);
  const serialized = values.get('metra.daily.pending-submission.v1');
  assert.ok(serialized);
  assert.equal(serialized.includes(fingerprint), false);
  const afterReload = await getOrCreateDailySubmissionKey(fingerprint, null, storage, webcrypto);
  assert.equal(afterReload.idempotencyKey, first.idempotencyKey);
  assert.equal(afterReload.fingerprint, first.fingerprint);
});

test('creates a new key when the logical report changes', async () => {
  const { webcrypto } = require('node:crypto');
  const values = new Map();
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) };
  const first = await getOrCreateDailySubmissionKey('report-A', null, storage, webcrypto);
  const changed = await getOrCreateDailySubmissionKey('report-B', null, storage, webcrypto);
  assert.notEqual(changed.idempotencyKey, first.idempotencyKey);
  assert.notEqual(changed.fingerprint, first.fingerprint);
});

test('retains same-page retry protection when session storage is unavailable', async () => {
  const { webcrypto } = require('node:crypto');
  const first = await getOrCreateDailySubmissionKey('report-A', null, undefined, webcrypto);
  const retry = await getOrCreateDailySubmissionKey('report-A', first, undefined, webcrypto);
  assert.equal(retry.idempotencyKey, first.idempotencyKey);
});

test('extracts server validation detail and bounds the displayed message', () => {
  assert.equal(getSubmissionErrorMessage({ status: 422, error: { detail: 'قيمة درجة الحرارة خارج المجال المسموح.' } }, 'رفض عام'), 'قيمة درجة الحرارة خارج المجال المسموح.');
  assert.equal(getSubmissionErrorMessage({ status: 400, error: { errors: { temperature: ['درجة الحرارة مطلوبة.'] } } }, 'رفض عام'), 'درجة الحرارة مطلوبة.');
  assert.equal(getSubmissionErrorMessage({ status: 403, error: 'لا تملك صلاحية الإرسال.' }, 'رفض عام'), 'لا تملك صلاحية الإرسال.');
  assert.equal(getSubmissionErrorMessage({ status: 422 }, 'رفض عام'), 'رفض عام');
  assert.equal(getSubmissionErrorMessage(null, 'رفض عام'), 'رفض عام');
});
