export type DailyOfflineState = 'pending' | 'sending' | 'blocked';

export interface DailyOfflineSubmission {
  idempotencyKey: string;
  observationType?: 'daily' | 'hourly';
  stationId: string;
  stationName: string;
  reportDate: string;
  reportType: string;
  observedAt: string;
  payload: Record<string, unknown>;
  createdAt: string;
  attempts: number;
  state: DailyOfflineState;
  lastError?: string;
}

/**
 * Durable browser-side outbox. It stores only user-submitted observation data
 * and the idempotency key; never store access tokens or service-role secrets.
 */
export class DailyOfflineQueue {
  private readonly databaseName = 'metra-offline-outbox';
  private readonly storeName = 'daily-submissions';
  private readonly stationStoreName = 'station-catalogue';
  private readonly syncLockStoreName = 'sync-locks';
  private database?: Promise<IDBDatabase>;

  async enqueue(item: DailyOfflineSubmission): Promise<void> {
    const db = await this.open();
    await this.request<void>(db, 'readwrite', store => store.put(item));
  }

  async list(): Promise<DailyOfflineSubmission[]> {
    const db = await this.open();
    const items = await this.request<DailyOfflineSubmission[]>(db, 'readonly', store => store.getAll());
    return items.sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  }

  async cacheStations(stations: unknown[]): Promise<void> {
    const db = await this.open();
    await this.request<void>(db, 'readwrite', store => store.put({ id: 'latest', stations, cachedAt: new Date().toISOString() }), this.stationStoreName);
  }

  async getCachedStations<T>(): Promise<T[]> {
    const db = await this.open();
    const cached = await this.request<{ stations?: T[] } | undefined>(db, 'readonly', store => store.get('latest'), this.stationStoreName);
    return Array.isArray(cached?.stations) ? cached.stations : [];
  }


  // A short IndexedDB lease prevents daily and hourly pages from draining the
  // shared outbox concurrently. Server idempotency remains the final safeguard.
  async acquireSyncLease(owner: string, leaseMs = 120_000): Promise<boolean> {
    const db = await this.open();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(this.syncLockStoreName, 'readwrite');
      const store = tx.objectStore(this.syncLockStoreName);
      const request = store.get('observations');
      let acquired = false;
      request.onsuccess = () => {
        const current = request.result as { owner?: string; expiresAt?: number } | undefined;
        const now = Date.now();
        if (!current || !current.expiresAt || current.expiresAt <= now || current.owner === owner) {
          store.put({ id: 'observations', owner, expiresAt: now + leaseMs });
          acquired = true;
        }
      };
      request.onerror = () => reject(request.error ?? new Error('تعذر قراءة قفل المزامنة.'));
      tx.oncomplete = () => resolve(acquired);
      tx.onerror = () => reject(tx.error ?? new Error('فشلت معاملة قفل المزامنة.'));
      tx.onabort = () => reject(tx.error ?? new Error('أُلغيت معاملة قفل المزامنة.'));
    });
  }

  async releaseSyncLease(owner: string): Promise<void> {
    const db = await this.open();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(this.syncLockStoreName, 'readwrite');
      const store = tx.objectStore(this.syncLockStoreName);
      const request = store.get('observations');
      request.onsuccess = () => {
        const current = request.result as { owner?: string } | undefined;
        if (current?.owner === owner) store.delete('observations');
      };
      request.onerror = () => reject(request.error ?? new Error('تعذر قراءة قفل المزامنة.'));
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error ?? new Error('فشلت معاملة تحرير قفل المزامنة.'));
      tx.onabort = () => reject(tx.error ?? new Error('أُلغيت معاملة تحرير قفل المزامنة.'));
    });
  }

  async update(item: DailyOfflineSubmission): Promise<void> {
    await this.enqueue(item);
  }

  async remove(idempotencyKey: string): Promise<void> {
    const db = await this.open();
    await this.request<void>(db, 'readwrite', store => store.delete(idempotencyKey));
  }

  private open(): Promise<IDBDatabase> {
    if (typeof indexedDB === 'undefined') {
      return Promise.reject(new Error('التخزين المحلي غير متاح في هذا المتصفح.'));
    }
    if (!this.database) {
      this.database = new Promise((resolve, reject) => {
        const request = indexedDB.open(this.databaseName, 3);
        request.onupgradeneeded = () => {
          const db = request.result;
          if (!db.objectStoreNames.contains(this.storeName)) {
            db.createObjectStore(this.storeName, { keyPath: 'idempotencyKey' });
          }
          if (!db.objectStoreNames.contains(this.stationStoreName)) {
            db.createObjectStore(this.stationStoreName, { keyPath: 'id' });
          }
          if (!db.objectStoreNames.contains(this.syncLockStoreName)) {
            db.createObjectStore(this.syncLockStoreName, { keyPath: 'id' });
          }
        };
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error ?? new Error('تعذر فتح صندوق الإرسال المحلي.'));
        request.onblocked = () => reject(new Error('تحديث التخزين المحلي محجوب بواسطة تبويب آخر.'));
      });
    }
    return this.database;
  }

  private request<T>(
    db: IDBDatabase,
    mode: IDBTransactionMode,
    operation: (store: IDBObjectStore) => IDBRequest,
    storeName = this.storeName
  ): Promise<T> {
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, mode);
      const request = operation(transaction.objectStore(storeName));
      let result!: T;
      request.onsuccess = () => { result = request.result as T; };
      request.onerror = () => reject(request.error ?? new Error('فشلت عملية صندوق الإرسال المحلي.'));
      transaction.oncomplete = () => resolve(result);
      transaction.onerror = () => reject(transaction.error ?? new Error('فشلت معاملة التخزين المحلي.'));
      transaction.onabort = () => reject(transaction.error ?? new Error('أُلغيت عملية التخزين المحلي.'));
    });
  }
}
