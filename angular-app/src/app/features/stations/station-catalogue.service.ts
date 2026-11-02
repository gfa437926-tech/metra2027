import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { Injectable, InjectionToken, inject } from '@angular/core';
import { firstValueFrom, timeout } from 'rxjs';
import {
  StationCatalogueItem,
  StationCataloguePage,
  StationCatalogueQuery,
  StationSourceKind
} from './station-catalogue.models';

/** Keep false until the API endpoint and its permission-enforcing store are deployed. */
export const STATION_CATALOGUE_ENDPOINT_ENABLED = new InjectionToken<boolean>(
  'STATION_CATALOGUE_ENDPOINT_ENABLED',
  { providedIn: 'root', factory: () => false }
);

export const STATION_CATALOGUE_API_BASE_URL = new InjectionToken<string>(
  'STATION_CATALOGUE_API_BASE_URL',
  { providedIn: 'root', factory: () => '/api/v1' }
);

export class StationCatalogueHttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
    this.name = 'StationCatalogueHttpError';
  }
}

@Injectable({ providedIn: 'root' })
export class StationCatalogueService {
  private readonly http = inject(HttpClient);
  private readonly enabled = inject(STATION_CATALOGUE_ENDPOINT_ENABLED);
  private readonly baseUrl = inject(STATION_CATALOGUE_API_BASE_URL);

  get isConfigured(): boolean {
    return this.enabled;
  }

  async readPage(query: StationCatalogueQuery = {}): Promise<StationCataloguePage> {
    if (!this.enabled) {
      throw new StationCatalogueHttpError(0, 'Station catalogue API is not configured.');
    }

    let params = new HttpParams().set('pageSize', String(query.pageSize ?? 50));
    if (query.sourceKind) params = params.set('sourceKind', query.sourceKind);
    if (query.namePrefix) params = params.set('namePrefix', query.namePrefix);
    if (query.cursor) params = params.set('cursor', query.cursor);

    const base = this.baseUrl.endsWith('/') ? this.baseUrl.slice(0, -1) : this.baseUrl;
    try {
      const value = await firstValueFrom(
        this.http.get<unknown>(base + '/stations', {
          params,
          withCredentials: true
        }).pipe(timeout({ first: 15000 }))
      );
      return this.normalizePage(value);
    } catch (error: unknown) {
      if (error instanceof StationCatalogueHttpError) throw error;
      if (error instanceof HttpErrorResponse) {
        throw new StationCatalogueHttpError(error.status, 'Station catalogue request failed.');
      }
      throw new StationCatalogueHttpError(0, 'Station catalogue service is unavailable.');
    }
  }

  private normalizePage(value: unknown): StationCataloguePage {
    if (!value || typeof value !== 'object') {
      throw new StationCatalogueHttpError(502, 'Invalid station catalogue response.');
    }
    const raw = value as Record<string, unknown>;
    if (!Array.isArray(raw['items']) || typeof raw['hasMore'] !== 'boolean') {
      throw new StationCatalogueHttpError(502, 'Invalid station catalogue response.');
    }
    const nextCursor = raw['nextCursor'];
    if ((raw['hasMore'] && (typeof nextCursor !== 'string' || !nextCursor.trim())) ||
        (!raw['hasMore'] && nextCursor !== null && nextCursor !== undefined) ||
        (nextCursor !== null && nextCursor !== undefined &&
          (typeof nextCursor !== 'string' || nextCursor.length > 2048 ||
           nextCursor !== nextCursor.trim() ||
           /[\u0000-\u001f\u007f-\u009f]/.test(nextCursor)))) {
      throw new StationCatalogueHttpError(502, 'Invalid station catalogue cursor.');
    }

    const items = raw['items'].map(item => this.normalizeItem(item));
    const identities = new Set<string>();
    for (const item of items) {
      const key = item.sourceKind + ':' + item.sourceRecordId;
      if (identities.has(key)) {
        throw new StationCatalogueHttpError(502, 'Duplicate station source identity.');
      }
      identities.add(key);
    }
    return {
      items: Object.freeze(items),
      hasMore: raw['hasMore'],
      nextCursor: typeof nextCursor === 'string' ? nextCursor : null
    };
  }

  private normalizeItem(value: unknown): StationCatalogueItem {
    if (!value || typeof value !== 'object') {
      throw new StationCatalogueHttpError(502, 'Invalid station catalogue item.');
    }
    const raw = value as Record<string, unknown>;
    const sourceKind = this.normalizeSourceKind(raw['sourceKind']);
    const sourceRecordId = raw['sourceRecordId'];
    const displayName = raw['displayName'];
    const latitude = raw['latitude'];
    const longitude = raw['longitude'];
    const elevation = raw['elevationMetres'];
    const sourceStationType = raw['sourceStationType'];
    const sourceCode = raw['sourceCode'];

    if (typeof sourceRecordId !== 'string' || !/^[A-Za-z0-9._:-]{1,128}$/.test(sourceRecordId) ||
        typeof displayName !== 'string' || !displayName.trim() || displayName.length > 256 ||
        /[\u0000-\u001f\u007f-\u009f]/.test(displayName) ||
        !this.validOptionalText(sourceStationType, 128) ||
        !this.validOptionalText(sourceCode, 128) ||
        !this.validCoordinatePair(latitude, longitude) ||
        !(elevation === null || elevation === undefined ||
          (typeof elevation === 'number' && Number.isFinite(elevation) && elevation >= -500 && elevation <= 10000))) {
      throw new StationCatalogueHttpError(502, 'Invalid station catalogue fields.');
    }
    return Object.freeze({
      sourceKind,
      sourceRecordId,
      displayName,
      sourceStationType: typeof sourceStationType === 'string' ? sourceStationType : null,
      sourceCode: typeof sourceCode === 'string' ? sourceCode : null,
      latitude: typeof latitude === 'number' ? latitude : null,
      longitude: typeof longitude === 'number' ? longitude : null,
      elevationMetres: typeof elevation === 'number' ? elevation : null
    });
  }

  private normalizeSourceKind(value: unknown): StationSourceKind {
    if (value === 0 || value === 'Classic' || value === 'classic') return 'classic';
    if (value === 1 || value === 'Automatic' || value === 'automatic') return 'automatic';
    throw new StationCatalogueHttpError(502, 'Unknown station source kind.');
  }

  private validOptionalText(value: unknown, maxLength: number): boolean {
    return value === null || value === undefined ||
      (typeof value === 'string' && value.length <= maxLength &&
       !/[\u0000-\u001f\u007f-\u009f]/.test(value));
  }

  private validCoordinatePair(latitude: unknown, longitude: unknown): boolean {
    if (latitude === null || latitude === undefined ||
        longitude === null || longitude === undefined) {
      return (latitude === null || latitude === undefined) &&
        (longitude === null || longitude === undefined);
    }
    return typeof latitude === 'number' && Number.isFinite(latitude) &&
      latitude >= -90 && latitude <= 90 &&
      typeof longitude === 'number' && Number.isFinite(longitude) &&
      longitude >= -180 && longitude <= 180;
  }
}
