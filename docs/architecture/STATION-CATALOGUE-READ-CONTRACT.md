# METRA unified station catalogue read contract

## Status and evidence

This is a provider-independent, read-only application contract. It does not approve a physical schema, canonical station identifiers, source crosswalk, API route, production adapter, or station-management mutation workflow.

The read-only legacy evidence recorded in `LEGACY-SUPABASE-READ-ONLY-REVIEW.md` reports 29 records in `public.stations` (classic) and 33 in `public.fieldclimate_stations` (automatic). Seventeen classic records have both coordinates; twelve do not. All 33 automatic records have coordinates. The classic `station_type` field was NULL for all 29 observed records. These are source counts, not a canonical station count.

## Source preservation

The API projection represents the source class explicitly as Classic or Automatic and preserves the source record identifier. The source class describes provenance, not physical identity. Equal display names or equal source-local IDs across the two source collections do not establish that records represent the same station.

The contract deliberately omits a canonical station ID until an owner-approved crosswalk exists. It also preserves optional raw source type and code values without interpreting them. No source record is silently removed, merged, renamed, or reclassified.

## Projection

Each item contains:
- source class (Classic or Automatic);
- source-local record identifier;
- original display name;
- optional raw source station-type metadata;
- optional source code;
- nullable latitude and longitude;
- nullable elevation in metres.

Coordinates must either both be absent or both present and within geographic ranges. Missing coordinates remain missing. No city-centre or inferred coordinates are permitted. Display names are preserved as source labels; no canonical label is selected by this contract.

## Query and paging

The query supports optional source-class filtering, a literal display-name prefix, page size 1–100, and an opaque continuation cursor. The trusted store must use deterministic keyset order `SourceKind ASC, SourceRecordId ASC`. Cursor integrity is validated and the cursor is bound to actor identity and every normalized filter. Offset paging is not used.

The application service resolves the actor from the authenticated server context. The store must enforce the approved station-catalogue read permission on every page. No permission code, role, or client-side access rule is invented here.

## Validation and privacy

The query service propagates the request cancellation token to both the authenticated actor-context provider and the trusted read store. If identity resolution is cancelled, the store must not be called. Hosting adapters must preserve cancellation rather than translating it into an authorization success or retrying a cancelled read.

The service rejects unknown source kinds, malformed identifiers, invalid coordinate pairs/ranges, invalid optional metadata, duplicate source-local identities, out-of-order pages, filter leakage, oversized pages, and inconsistent/repeated cursors. Results are returned as read-only collections.

## Map and client integration requirements

Angular and Flutter should consume the same API projection. A map must use a distinct visual marker for Classic and Automatic source classes while keeping both classes in the same station layer and catalogue. Records without coordinates remain visible in the station list and must not be plotted at fabricated positions. A future canonical crosswalk may relate multiple source records to one canonical station, but that relation requires owner approval and explicit reconciliation evidence.

## Activation gates

HTTP-level security tests must prove that anonymous requests to both catalogue and source-qualified detail routes receive an authentication challenge before route handlers can expose data or dependency-registration state. Application-service tests additionally prove that cancellation is propagated and that identity-resolution cancellation does not invoke the read store.


No production source adapter, endpoint mapping, dependency-injection registration, database query, schema migration, RLS policy, grant, seed data, station mutation, or cross-source merge is introduced. Activation requires review of the source schemas, authoritative permission code, source-field mapping, crosswalk rules, and integration tests. The legacy project remains read-only and untouched.
## Map projection contract

`StationMapProjection` is a pure projection over the validated catalogue page. It creates one marker collection containing both source classes, with source-qualified marker keys and explicit source kind for distinct classic/automatic icons. It returns every record without a complete verified coordinate pair in a separate list collection. It never supplies default coordinates, approximates a city centre, or merges records by name. Invalid or partial coordinate pairs are rejected rather than plotted.


## Source-qualified station detail read contract

`StationDetailQueryService` accepts the pair `(SourceKind, SourceRecordId)` as the only station lookup key. The source namespace is mandatory: a Classic record and an Automatic record with the same local identifier remain distinct, and the read store must never fall back across source classes or resolve a record by display name.

The trusted detail store must enforce the approved detail-read permission and the actor's authoritative station scope within the same read operation. It returns no record both for a missing record and for a record outside the actor's visible scope, preventing the detail lookup from becoming an existence oracle. Actor identity is derived from the authenticated server context, never from query input.

The application service validates the source key, actor identifier, returned source-qualified identity, display name, optional source metadata, coordinate pair/ranges, and elevation bounds. A mismatched source key or malformed store projection fails closed. Missing coordinates and optional metadata remain null. The protected HTTP routes are mapped, but no DI registration, production read adapter, database schema change, or mutation workflow has been added; the routes remain unavailable (503) until the approved trusted dependencies are supplied.


## Angular station catalogue client

The Angular application now includes a unified station catalogue screen at `/stations`, with a navigation entry under system administration. The screen presents one combined list, source-specific visual labels for Classic and Automatic records, source-local identifiers, source codes, coordinates, elevation, and an explicit no-coordinate state. Name-prefix and source-class filters are sent to the API so they apply across the full catalogue rather than only the pages already loaded. The user explicitly applies a name search; changing source class reloads the first page. Continuation requests preserve the active filters, reject duplicate source identities across pages, and detect repeated/cyclic cursors instead of silently discarding inconsistent records.

The client reads only from the planned `GET /api/v1/stations` contract and preserves cursor pagination. It normalizes numeric or named enum serialization for `StationCatalogueSourceKind`, validates the response envelope and every station's source identity, optional metadata, coordinate pair, and elevation, and rejects duplicate source-qualified keys. It sends credentials and maps 401/403 separately from service failures.

Activation is deliberately disabled by default through `STATION_CATALOGUE_ENDPOINT_ENABLED`. Protected HTTP routes now exist at `GET /api/v1/stations` and `GET /api/v1/stations/{sourceKind}/{sourceRecordId}`. They require authorization and return 503 until the approved actor-context providers, query services, and permission-enforcing stores are registered. The screen therefore displays an explicit unconfigured state rather than mock station records. The geographic map provider and actual map renderer are also not selected or activated. The screen documents the intended two-marker distinction and retains unlocated stations, but must not be described as a live map until the map provider and API integration are approved and implemented.
