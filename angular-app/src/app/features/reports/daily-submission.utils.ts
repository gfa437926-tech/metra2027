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
