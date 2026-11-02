# Station Catalogue Frontend Validation

## Scope

This checklist defines the frontend acceptance boundary for the unified classic/automatic station catalogue. It is a verification aid, not evidence that every scenario has already been executed.

## Data contract

The Angular client consumes `GET /api/v1/stations` through `StationCatalogueService`.

- A source record is identified by the pair `(sourceKind, sourceRecordId)`; names are not identifiers.
- `sourceKind` is `classic` or `automatic` (the API may serialize the enum as its documented numeric or string form).
- Coordinates are either both present and in geographic range, or both absent.
- Elevation is nullable and, when present, is constrained to -500 through 10,000 metres.
- Optional source metadata remains nullable and is not inferred.
- `hasMore` and `nextCursor` must agree. A continuation cursor is bounded, trimmed, and contains no control characters.
- Client requests are rejected before network access unless page size is an integer from 1 through 100, source kind is recognized, name prefix is non-empty after trimming and at most 128 characters, and cursor is at most 2,048 characters with no control characters. Control characters in the original name-prefix input are rejected before trimming so whitespace-like C1 controls cannot be silently removed. The backend applies the same raw-input rule to cursors: supplied empty, padded, whitespace-only, or control-character cursors are rejected before normalization.
- Responses may not exceed the requested page size, claim more pages while returning no records, or repeat the cursor used for the current request.
- Duplicate source identities within a page or across pages are invalid.
- The client does not infer canonical station identity, merge records by display name, or synthesize missing coordinates.
- Source filter buttons expose their selected state through `aria-pressed`; the catalogue panel exposes request activity through `aria-busy`.
- The catalogue table has a descriptive caption and explicitly scoped column headers; the initial loading state is announced through a polite live status.

## Loading and recovery behavior

| Scenario | Expected behavior |
| --- | --- |
| Endpoint disabled | Show the unconfigured state; do not fabricate rows. |
| Initial request | Show initial loading state. |
| Initial request succeeds | Show returned rows and pagination state. |
| Initial request returns 401 | Show unauthenticated state. |
| Initial request returns 403 | Show forbidden state. |
| Initial request fails otherwise | Show unavailable state and allow a fresh load. |
| Next page is requested | Keep already-loaded rows visible and disable duplicate next-page requests. |
| Next page succeeds | Append rows only after validating cross-page identities and cursor progression. |
| Next page fails transiently | Preserve current rows and expose a retry action. |
| Next page returns 401 or 403 | Stop presenting protected rows and transition to the corresponding access state. |
| Next page contains malformed data, duplicate identities, or a cursor cycle | Preserve current rows, require a fresh catalogue load, and do not retry the same invalid continuation indefinitely. |
| Filters change during a request | The newer request supersedes the older request; stale responses must not overwrite the current view. |

## Manual acceptance checklist

- [ ] Classic and automatic records are shown in one catalogue with distinct source labels.
- [ ] A classic record and an automatic record with the same display name remain separate records.
- [ ] Records without coordinates remain visible and are not assigned fallback coordinates.
- [ ] Latitude/longitude partial pairs and out-of-range coordinates are rejected.
- [ ] Invalid source kinds, source identifiers, control characters, and out-of-range elevations are rejected.
- [ ] The first page can be loaded without a cursor.
- [ ] A valid continuation appends records without replacing the first page.
- [ ] A duplicate identity across pages is rejected.
- [ ] Repeated or cyclic cursors cannot create an infinite pagination loop.
- [ ] A transient next-page failure leaves the existing rows visible and can be retried.
- [ ] A malformed next-page response requires a fresh load.
- [ ] A filter change invalidates an in-flight response from the previous filter.
- [ ] A 401/403 response during pagination ends display of the protected catalogue.
- [ ] The catalogue endpoint remains disabled until the production API and permission-enforcing read store are deployed and approved.

## Current implementation notes

- The endpoint feature token defaults to disabled.
- The component keeps the loaded catalogue visible while fetching subsequent pages.
- It detects duplicate identities across pages and cursor cycles.
- Invalid continuation responses require a full catalogue reload; transient failures can be retried.
- The Angular project now uses the Angular 20 `@angular/build:karma` builder with Jasmine and Karma. This is a test-only build target and is not a production runtime dependency. `npm test` runs the station catalogue service specs in non-watch mode, and Angular CI executes this suite before the production build. The configured `npm audit --audit-level=high` gate passes with this runner; npm currently still reports moderate-severity transitive advisories in the Angular CLI/Karma dependency tree, which require a separately planned toolchain upgrade rather than an unsafe forced major-version change. The service suite covers disabled-endpoint behavior, invalid query rejection before network access, credentialed requests, response normalization, duplicate identities, invalid coordinate pairs, cursor cycles, pagination metadata, and authentication errors. The component suite covers the unconfigured state, source-preserving same-name records, missing-coordinate counts, source-filter accessibility state, and duplicate identities across pages.
- The live map remains a separate integration gate. Map markers must be built from verified coordinate pairs and use source-specific visual identities.

## Release gates

Do not enable the endpoint or present the catalogue as production-connected until all of the following are true:

1. The backend route is backed by a trusted read-store implementation.
2. Every page re-evaluates the approved catalogue-read permission for the authenticated actor.
3. Cursor integrity is bound to the actor and active filters.
4. Source ordering is deterministic and stable between pages.
5. The approved source inventory and canonical identity/crosswalk policy are documented.
6. Angular acceptance scenarios above are exercised in a repeatable test environment.
7. Map provider, attribution, accessibility, and marker behavior are approved.
