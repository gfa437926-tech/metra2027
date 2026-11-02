import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { Injectable, InjectionToken, inject } from '@angular/core';
import { firstValueFrom, timeout } from 'rxjs';
import {
  StationCataloguePage,
  StationCatalogueQuery
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
      const page = await firstValueFrom(
        this.http.get<StationCataloguePage>(`${base}/stations`, {
          params,
          withCredentials: true
        }).pipe(timeout({ first: 15000 }))
      );
      if (!page || !Array.isArray(page.items) ||
          typeof page.hasMore !== 'boolean' ||
          (page.hasMore && (typeof page.nextCursor !== 'string' || !page.nextCursor))) {
        throw new StationCatalogueHttpError(502, 'Invalid station catalogue response.');
      }
      return page;
    } catch (error: unknown) {
      if (error instanceof StationCatalogueHttpError) throw error;
      if (error instanceof HttpErrorResponse) {
        throw new StationCatalogueHttpError(error.status, 'Station catalogue request failed.');
      }
      throw new StationCatalogueHttpError(0, 'Station catalogue service is unavailable.');
    }
  }
}
