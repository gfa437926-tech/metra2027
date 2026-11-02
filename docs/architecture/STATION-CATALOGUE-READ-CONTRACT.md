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

The service rejects unknown source kinds, malformed identifiers, invalid coordinate pairs/ranges, invalid optional metadata, duplicate source-local identities, out-of-order pages, filter leakage, oversized pages, and inconsistent/repeated cursors. Results are returned as read-only collections.

## Map and client integration requirements

Angular and Flutter should consume the same API projection. A map must use a distinct visual marker for Classic and Automatic source classes while keeping both classes in the same station layer and catalogue. Records without coordinates remain visible in the station list and must not be plotted at fabricated positions. A future canonical crosswalk may relate multiple source records to one canonical station, but that relation requires owner approval and explicit reconciliation evidence.

## Activation gates

No production source adapter, endpoint mapping, dependency-injection registration, database query, schema migration, RLS policy, grant, seed data, station mutation, or cross-source merge is introduced. Activation requires review of the source schemas, authoritative permission code, source-field mapping, crosswalk rules, and integration tests. The legacy project remains read-only and untouched.
## Map projection contract

`StationMapProjection` is a pure projection over the validated catalogue page. It creates one marker collection containing both source classes, with source-qualified marker keys and explicit source kind for distinct classic/automatic icons. It returns every record without a complete verified coordinate pair in a separate list collection. It never supplies default coordinates, approximates a city centre, or merges records by name. Invalid or partial coordinate pairs are rejected rather than plotted.


## Source-qualified station detail read contract

`StationDetailQueryService` accepts the pair `(SourceKind, SourceRecordId)` as the only station lookup key. The source namespace is mandatory: a Classic record and an Automatic record with the same local identifier remain distinct, and the read store must never fall back across source classes or resolve a record by display name.

The trusted detail store must enforce the approved detail-read permission and the actor's authoritative station scope within the same read operation. It returns no record both for a missing record and for a record outside the actor's visible scope, preventing the detail lookup from becoming an existence oracle. Actor identity is derived from the authenticated server context, never from query input.

The application service validates the source key, actor identifier, returned source-qualified identity, display name, optional source metadata, coordinate pair/ranges, and elevation bounds. A mismatched source key or malformed store projection fails closed. Missing coordinates and optional metadata remain null. This contract adds no endpoint, DI registration, database adapter, schema, or mutation workflow; activation remains subject to the gates above.
