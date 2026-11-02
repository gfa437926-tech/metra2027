import { provideHttpClient, withInterceptorsFromDi } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  STATION_CATALOGUE_ENDPOINT_ENABLED,
  STATION_CATALOGUE_API_BASE_URL,
  StationCatalogueHttpError,
  StationCatalogueService
} from './station-catalogue.service';

describe('StationCatalogueService', () => {
  let service: StationCatalogueService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptorsFromDi()),
        provideHttpClientTesting(),
        { provide: STATION_CATALOGUE_ENDPOINT_ENABLED, useValue: true },
        { provide: STATION_CATALOGUE_API_BASE_URL, useValue: '/api/v1' }
      ]
    });
    service = TestBed.inject(StationCatalogueService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    http.verify();
    TestBed.resetTestingModule();
  });

  it('keeps the endpoint disabled unless explicitly enabled', async () => {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        { provide: STATION_CATALOGUE_ENDPOINT_ENABLED, useValue: false }
      ]
    });
    const disabled = TestBed.inject(StationCatalogueService);

    await expect(disabled.readPage()).rejects.toMatchObject({ status: 0 });
    TestBed.inject(HttpTestingController).expectNone('/api/v1/stations');
  });

  it('rejects malformed page size, C1 prefix controls and cursors before network access', async () => {
    await expect(service.readPage({ pageSize: 0 })).rejects.toMatchObject({ status: 400 });
    await expect(service.readPage({ pageSize: 101 })).rejects.toMatchObject({ status: 400 });
    await expect(service.readPage({ namePrefix: 'محطة\u0085' })).rejects.toMatchObject({ status: 400 });
    await expect(service.readPage({ cursor: 'cursor\u009f' })).rejects.toMatchObject({ status: 400 });
    await expect(service.readPage({ cursor: '   ' })).rejects.toMatchObject({ status: 400 });
    http.expectNone('/api/v1/stations');
  });

  it('sends a validated query with cookie credentials and normalizes a valid page', async () => {
    const resultPromise = service.readPage({
      pageSize: 25,
      sourceKind: 'classic',
      namePrefix: ' دمشق '
    });
    const request = http.expectOne(req =>
      req.url === '/api/v1/stations' &&
      req.params.get('pageSize') === '25' &&
      req.params.get('sourceKind') === 'classic' &&
      req.params.get('namePrefix') === 'دمشق'
    );
    expect(request.request.method).toBe('GET');
    expect(request.request.withCredentials).toBe(true);
    request.flush({
      items: [{
        sourceKind: 'classic',
        sourceRecordId: 'station-1',
        displayName: 'دمشق',
        sourceStationType: null,
        sourceCode: null,
        latitude: 33.5,
        longitude: 36.3,
        elevationMetres: null
      }],
      hasMore: false,
      nextCursor: null
    });

    const result = await resultPromise;
    expect(result.items).toHaveLength(1);
    expect(result.items[0].sourceKind).toBe('classic');
    expect(result.items[0].latitude).toBe(33.5);
    expect(Object.isFrozen(result.items)).toBe(true);
  });

  it('rejects duplicate source identities and invalid coordinate pairs', async () => {
    const duplicatePromise = service.readPage();
    http.expectOne('/api/v1/stations?pageSize=50').flush({
      items: [
        { sourceKind: 'classic', sourceRecordId: '1', displayName: 'أ', latitude: null, longitude: null },
        { sourceKind: 'Classic', sourceRecordId: '1', displayName: 'ب', latitude: null, longitude: null }
      ],
      hasMore: false,
      nextCursor: null
    });
    await expect(duplicatePromise).rejects.toMatchObject({ status: 502 });

    const coordinatePromise = service.readPage();
    http.expectOne('/api/v1/stations?pageSize=50').flush({
      items: [{
        sourceKind: 'automatic',
        sourceRecordId: '2',
        displayName: 'محطة',
        latitude: 33,
        longitude: null
      }],
      hasMore: false,
      nextCursor: null
    });
    await expect(coordinatePromise).rejects.toMatchObject({ status: 502 });
  });

  it('rejects cursor cycles and inconsistent pagination metadata', async () => {
    const cyclePromise = service.readPage({ cursor: 'page-1' });
    http.expectOne(req => req.params.get('cursor') === 'page-1').flush({
      items: [],
      hasMore: true,
      nextCursor: 'page-1'
    });
    await expect(cyclePromise).rejects.toMatchObject({ status: 502 });

    const inconsistentPromise = service.readPage();
    http.expectOne('/api/v1/stations?pageSize=50').flush({
      items: [],
      hasMore: true,
      nextCursor: null
    });
    await expect(inconsistentPromise).rejects.toMatchObject({ status: 502 });
  });

  it('maps authentication failures to typed HTTP errors', async () => {
    const resultPromise = service.readPage();
    http.expectOne('/api/v1/stations?pageSize=50').flush(
      { message: 'Unauthorized' },
      { status: 401, statusText: 'Unauthorized' }
    );
    await expect(resultPromise).rejects.toBeInstanceOf(StationCatalogueHttpError);
    await expect(resultPromise).rejects.toMatchObject({ status: 401 });
  });
});
