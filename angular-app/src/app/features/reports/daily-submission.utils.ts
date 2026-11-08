export interface ConfirmedDailySubmission {
  id: string;
  status: 'submitted';
  replayed?: boolean;
}

const UUID_V4_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Generate an RFC 4122 UUID v4 using a cryptographically secure source only. */
export function createIdempotencyKey(cryptoApi: Crypto | undefined = globalThis.crypto): string {
  if (typeof cryptoApi?.randomUUID === 'function') return cryptoApi.randomUUID();
  if (typeof cryptoApi?.getRandomValues !== 'function') {
    throw new Error('هذا المتصفح لا يوفر مولّداً عشوائياً آمناً؛ حدّث المتصفح أو استخدم اتصالاً آمناً قبل إرسال النشرة.');
  }

  const bytes = cryptoApi.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, byte => byte.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/** A successful HTTP response alone is insufficient; require the persisted submission receipt. */
export function getConfirmedDailySubmission(result: unknown): ConfirmedDailySubmission | null {
  if (!result || typeof result !== 'object') return null;
  const candidate = result as { id?: unknown; status?: unknown; replayed?: unknown };
  if (typeof candidate.id !== 'string' || !UUID_V4_PATTERN.test(candidate.id) ||
      candidate.status !== 'submitted') return null;
  return {
    id: candidate.id,
    status: 'submitted',
    ...(typeof candidate.replayed === 'boolean' ? { replayed: candidate.replayed } : {})
  };
}

/** Keep the existing provisional UTC boundary mapping isolated and covered by tests. */
export function dailyObservedAtForReport(reportDate: string, reportType: string): string {
  const utcHour = reportType === '06utc' ? '06'
    : reportType === '18utc' ? '18' : '00';
  return new Date(`${reportDate}T${utcHour}:00:00.000Z`).toISOString();
}

export interface PendingDailySubmissionKey {
  fingerprint: string;
  idempotencyKey: string;
}

/** Reuse a pending key for the same report; persist only its SHA-256 hash and UUID. */
export async function getOrCreateDailySubmissionKey(
  fingerprint: string,
  pending: PendingDailySubmissionKey | null,
  storage?: Pick<Storage, 'getItem' | 'setItem'>,
  cryptoApi: Crypto | undefined = globalThis.crypto
): Promise<PendingDailySubmissionKey> {
  let fingerprintHash = '';
  let canPersistFingerprint = false;
  try {
    if (cryptoApi?.subtle && typeof TextEncoder !== 'undefined') {
      const digest = await cryptoApi.subtle.digest('SHA-256', new TextEncoder().encode(fingerprint));
      fingerprintHash = Array.from(new Uint8Array(digest))
        .map(byte => byte.toString(16).padStart(2, '0')).join('');
      canPersistFingerprint = true;
    }
  } catch {
    // Without Web Crypto, retain the raw fingerprint only in page memory.
  }
  if (!canPersistFingerprint) fingerprintHash = fingerprint;
  if (pending?.fingerprint === fingerprintHash) return pending;

  let activeStorage = storage;
  if (!activeStorage && canPersistFingerprint) {
    try { activeStorage = globalThis.sessionStorage; } catch { /* storage unavailable */ }
  }
  try {
    const stored = canPersistFingerprint ? activeStorage?.getItem('metra.daily.pending-submission.v1') : null;
    if (stored) {
      const parsed = JSON.parse(stored) as { fingerprintHash?: unknown; idempotencyKey?: unknown };
      if (parsed.fingerprintHash === fingerprintHash &&
          typeof parsed.idempotencyKey === 'string' &&
          UUID_V4_PATTERN.test(parsed.idempotencyKey)) {
        return { fingerprint: fingerprintHash, idempotencyKey: parsed.idempotencyKey };
      }
    }
  } catch {
    // Disabled or malformed storage must not prevent a valid submission.
  }

  const idempotencyKey = createIdempotencyKey(cryptoApi);
  const next = { fingerprint: fingerprintHash, idempotencyKey };
  try {
    if (canPersistFingerprint) {
      activeStorage?.setItem('metra.daily.pending-submission.v1', JSON.stringify({
        fingerprintHash, idempotencyKey
      }));
    }
  } catch {
    // In-memory retry protection remains available.
  }
  return next;
}

/** Extract a concise, user-safe validation message from Angular HTTP errors. */
export function getSubmissionErrorMessage(error: unknown, fallback: string): string {
  if (error && typeof error === 'object') {
    const candidate = error as { error?: unknown; message?: unknown; status?: unknown };
    const body = candidate.error;
    if (typeof body === 'string' && body.trim()) return body.trim().slice(0, 500);
    if (body && typeof body === 'object') {
      const details = body as { detail?: unknown; message?: unknown; title?: unknown; errors?: unknown };
      for (const value of [details.detail, details.message, details.title]) {
        if (typeof value === 'string' && value.trim()) return value.trim().slice(0, 500);
      }
      if (details.errors && typeof details.errors === 'object') {
        const messages = Object.values(details.errors as Record<string, unknown>)
          .flatMap(value => Array.isArray(value) ? value : [value])
          .filter((value): value is string => typeof value === 'string' && Boolean(value.trim()));
        if (messages.length) return messages.slice(0, 5).join(' · ').slice(0, 500);
      }
    }
    if (typeof candidate.message === 'string' && candidate.message.trim()) {
      const status = Number(candidate.status);
      return (Number.isFinite(status) && status > 0 ? `HTTP ${status}: ` : '') + candidate.message.trim().slice(0, 470);
    }
  }
  return fallback;
}
