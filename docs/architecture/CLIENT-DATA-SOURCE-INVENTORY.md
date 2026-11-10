# METRA 2027 — Client feature data-source inventory

**Audit timestamp (UTC):** 2026-11-11  
**Branch:** `assistant-12/system-integration-audit`  
**Method:** Read-only static inspection of route declarations, feature components, API services and Flutter navigation/screens. This inventory proves source wiring only; it does not prove successful runtime calls or persisted records.

## Classification

- **API wired (source):** feature invokes a typed client service that makes an authenticated HTTP request to the ASP.NET Core API. Runtime remains unverified.
- **Local / preview:** state, form validation, timer, export or browser storage only; no server persistence path was found in the inspected feature.
- **Explicitly unconnected:** component declares that no read/API source is connected.
- **Partial:** some operations use the API, while other actions remain local/preview.
- **Not fully traced:** route/service relationship requires further source inspection.

## Angular route-by-route findings

| Route / feature | Source evidence | Classification | Important boundary |
|---|---|---|---|
| `/login` | `features/auth/login.component.ts` injects `SupabaseAuthService`; auth service calls Supabase Auth password sign-in and exposes access token | API/provider wired (Supabase Auth) | Identity provider only; METRA API access still depends on configured HTTPS API and server authorization |
| `/register` | `registration.component.ts` uses Supabase Auth, `ObservationApiService` for station catalogue, and `RegistrationSubmissionApiService` for membership request | API wired (Auth + METRA API) | Account creation does not itself grant operational authorization; approval workflow is separate |
| `/` dashboard | `dashboard.component.ts` reads `currentUser` from browser `localStorage`; logout only removes that key; refresh only updates greeting text | Local / placeholder | This is not proof of the Supabase session or a server-side sign-out. Maintenance/about cards display “in transfer” notices rather than invoking services |
| `/phenomena/input` | `phenomena-input.component.ts` keeps `phenomena`, active timer and pause state in component memory; IDs use `local_`; page warns no DB connection | Local / preview | Start/pause/stop is not persisted; current phenomenon input is not wired to the API submission endpoint |
| `/phenomena` | `phenomena.component.ts` initializes `allPhenomena = []`; `refreshData()` is intentionally unavailable until approved API connection; filters/exports operate on in-memory collection | Explicitly unconnected / local view | No server read or persisted phenomenon source was evidenced |
| `/reports/hourly` | Imports `ObservationApiService`; loads station catalogue and calls `submitObservation(... observationType: 'hourly' ...)`; response ID required before submitted status | Partial: API submit + local preview list | Runtime depends on API/Auth configuration; displayed list is client-memory preview, not a queried history endpoint |
| `/reports/daily` | Imports `ObservationApiService`; `submitToServer()` submits daily observation; separate `submit()` creates D-#### draft; `saveDraft()` is page-memory only; sample-fill action exists | Partial: API submit + local drafts/sample data | Distinguish the actual server submit button from local draft/preview actions |
| `/reports/rainfall` | Component declares “وضع المعاينة”; form submits to `preview()`; no API service import in inspected file | Local / preview | No persistence path found |
| `/reports/climate` | Component declares an independent demo form; `submit()` validates and builds local values; no API service import | Local / preview | Not connected to a climate observation API |
| `/reports/monthly` | Component states source is not connected; station array is empty; search only changes a local message | Explicitly unconnected | No API read/query |
| `/reports/annual` | Component states no read service is connected; metrics are placeholders; `generate()` only validates local criteria | Explicitly unconnected | No API read/query or report calculation |
| `/agriculture` | Component explicitly says no DB/API connection; draft stored in `localStorage`; sample values are filled client-side | Local / preview | Browser-local draft is not a server record |
| `/soil-temperature` | Component explicitly says no API/database connection and no permanent record saving; `preview()` validates locally | Local / preview | No persistence path found |
| `/users` | Includes registration-review and authority-access components; these inject registration, station assignment, user directory and audit API services | API wired (management operations) | Source wiring exists; authorization and server behavior require runtime tests |
| `/observations/workflow` | `ObservationApiService.getReviewQueue()` and `decide()` called by workflow component | API wired (review) | Runtime/station-scope enforcement not tested in this audit |

## Flutter navigation and screen findings

| Screen | Source evidence | Classification | Important boundary |
|---|---|---|---|
| Authentication gate/login | `core/auth/metra_auth.dart` initializes Supabase Auth, persists session via `flutter_secure_storage`, listens to auth-state changes and injects current access token into `MetraApiClient` | API/provider wired (Supabase Auth) | No live login/session lifecycle test performed |
| Home overview | `features/home/metra_home.dart` displays static explanatory/status cards; live weather explicitly says not connected | Static / informational | No weather observation feed or operational metrics |
| Station directory/map | `station_directory_screen.dart` calls `getAllStationDirectory()` on `MetraApiClient`; supports station type filters, map/list and refresh | API wired (read) | Coordinates are rendered only when response contains valid coordinates |
| Observation review | `observation_review_screen.dart` loads `getReviewQueue()`, posts `decideObservation()` and refreshes after result | API wired (read/write) | Requires selected station UUID and server-side reviewer permission |
| Reports & analytics | Home navigation uses an information page stating operational reports are not enabled until an approved observation source is connected | Explicitly unconnected | No report API or calculations found |
| Account settings | Displays authenticated email and calls Supplied sign-out callback from Supabase Auth | API/provider wired (Auth) | Does not provide broader profile/role administration |

## Shared client API capability vs actual screen usage

The Flutter `MetraApiClient` exposes station directory, observation submit, review queue and decision methods. In the inspected navigation tree, station directory and review are used by screens; **no observation-entry screen was found invoking the Flutter submit method**. Therefore a client method existing is not evidence that a form is integrated.

Angular `ObservationApiService` exposes station directory, submit, review queue and decision methods. The hourly and daily pages use submit; the review workflow uses queue/decision; the other report pages listed above do not become integrated merely because the shared service exists.

## Prioritized integration gaps

1. **P0 — Dashboard identity:** replace display/authorization assumptions based on `localStorage.currentUser` with the authenticated Supabase session and server-derived profile/role; call real Supabase sign-out.
2. **P0 — Daily/hourly correctness:** add API-backed read/history and idempotent retry tests; ensure preview/draft rows cannot be mistaken for persisted submissions.
3. **P0 — Phenomena:** connect entry and list pages to the `phenomenon` observation type; define start/stop semantics and timezone rules before enabling operational use.
4. **P1 — Climate, rainfall, soil and agriculture:** define approved payload DTOs and endpoints, then wire screens; keep local drafts explicitly marked until then.
5. **P1 — Monthly/annual reports:** define authoritative approved-record read endpoints, aggregation rules, completeness and provenance metadata.
6. **P1 — Flutter parity:** add a real observation-entry screen before claiming parity with Angular; report screen must remain marked unavailable until a read/report contract exists.
7. **P1 — Users/admin:** exercise all registration, membership, assignment, user directory and audit paths against isolated API with positive/negative authorization tests.

## Verification and safety

- This is a static source inventory only; no browser/device runtime request was made.
- No unit, integration, E2E or build tests were run for this inventory.
- GitHub Actions were not run or verified for this inventory commit.
- No database, migration, production deployment or other assistant's application files were changed.
