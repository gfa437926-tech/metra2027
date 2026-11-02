export type StationSourceKind = 'classic' | 'automatic';

export interface StationCatalogueItem {
  readonly sourceKind: StationSourceKind;
  readonly sourceRecordId: string;
  readonly displayName: string;
  readonly sourceStationType: string | null;
  readonly sourceCode: string | null;
  readonly latitude: number | null;
  readonly longitude: number | null;
  readonly elevationMetres: number | null;
}

export interface StationCataloguePage {
  readonly items: readonly StationCatalogueItem[];
  readonly hasMore: boolean;
  readonly nextCursor: string | null;
}

export interface StationCatalogueQuery {
  readonly sourceKind?: StationSourceKind;
  readonly namePrefix?: string;
  readonly pageSize?: number;
  readonly cursor?: string;
}

export type StationCatalogueLoadState =
  | 'unconfigured'
  | 'loading'
  | 'loaded'
  | 'unauthenticated'
  | 'forbidden'
  | 'unavailable';
