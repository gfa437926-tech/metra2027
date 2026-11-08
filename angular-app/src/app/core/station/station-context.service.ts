import { Injectable } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

const STORAGE_KEY = 'metra.selectedStationId';

@Injectable({ providedIn: 'root' })
export class StationContextService {
  isUuid(value: string | null | undefined): boolean {
    return !!value &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
  }

  /**
   * Prefer explicit query stationId, then last selected station in this browser.
   * Never invent a station; return empty when unknown.
   */
  resolveStationId(route?: ActivatedRoute | null): string {
    const fromQuery = route?.snapshot.queryParamMap.get('stationId')
      ?? route?.snapshot.queryParamMap.get('station_id')
      ?? '';
    if (this.isUuid(fromQuery)) {
      this.remember(fromQuery);
      return fromQuery;
    }
    if (typeof localStorage === 'undefined') {
      return '';
    }
    try {
      const stored = localStorage.getItem(STORAGE_KEY) ?? '';
      if (this.isUuid(stored)) {
        return stored;
      }
      const raw = localStorage.getItem('currentUser');
      if (raw) {
        const user = JSON.parse(raw) as Record<string, unknown>;
        for (const key of ['station_id', 'stationId', 'selectedStationId']) {
          const candidate = String(user[key] ?? '');
          if (this.isUuid(candidate)) {
            this.remember(candidate);
            return candidate;
          }
        }
      }
    } catch {
      // ignore malformed session blobs
    }
    return '';
  }

  remember(stationId: string): void {
    if (!this.isUuid(stationId) || typeof localStorage === 'undefined') {
      return;
    }
    localStorage.setItem(STORAGE_KEY, stationId);
  }

  clear(): void {
    if (typeof localStorage === 'undefined') {
      return;
    }
    localStorage.removeItem(STORAGE_KEY);
  }
}
