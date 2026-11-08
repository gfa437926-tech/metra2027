const test = require('node:test');
const assert = require('node:assert/strict');
const {
  createIdempotencyKey,
  getConfirmedDailySubmission,
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
  assert.equal(getConfirmedDailySubmission(null), null);
});

test('maps daily report types to their current UTC timestamps', () => {
  assert.equal(dailyObservedAtForReport('2026-11-08', '24h'), '2026-11-08T00:00:00.000Z');
  assert.equal(dailyObservedAtForReport('2026-11-08', '06utc'), '2026-11-08T06:00:00.000Z');
  assert.equal(dailyObservedAtForReport('2026-11-08', '18utc'), '2026-11-08T18:00:00.000Z');
});
