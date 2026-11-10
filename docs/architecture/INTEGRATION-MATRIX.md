# METRA 2027 — Integration and contract matrix

**Audit date:** 2026-11-11 · **Baseline:** `main` · **Status vocabulary:** Implemented in source / Partially evidenced / Not evidenced / Blocked pending environment.

| Producer → Consumer | Contract / evidence inspected | Source-level status | Runtime status | Gap / next proof |
|---|---|---|---|---|
| Angular → Supabase Auth | `SupabaseAuthService`, password sign-in and access-token provider | Implemented in source | Not live-tested | Verify login, refresh, expiry, sign-out and revocation in isolated env |
| Flutter → Supabase Auth | `MetraAuthGate`, auth-state listener and secure session storage | Implemented in source | Not live-tested | Verify secure-storage lifecycle, refresh and sign-out on device |
| Angular → API station directory | `ObservationApiService.getStations()`, GET `/api/v1/stations` | Implemented in source; used by hourly/daily/register flows | Not live-tested | Authenticated browser request + response contract test |
| Angular → API submit | `submitObservation()`; hourly and daily forms call it | Partial: hourly/daily only | Not live-tested | Other report/phenomena forms are local or unconnected; verify payload contracts |
| Angular → API review | `getReviewQueue()`, `decide()` in observation workflow | Implemented in source | Not live-tested | Test station-scoped reviewer authorization and state transitions |
| Angular → API registration/admin | Registration, registration review, assignment, station user directory and audit services | Implemented in source | Not live-tested | Exercise each route and negative authorization cases |
| Angular → API phenomenon input/list | `phenomena-input` local timer; `phenomena.component` empty collection and no-op refresh | Not evidenced as API-connected | Not connected in inspected client | Wire `phenomenon` submission/read contract; define start/end and timezone behavior |
| Angular → API rainfall/climate/soil/agriculture | Components explicitly use preview/local forms; agriculture uses localStorage | Not connected | Not connected in inspected client | Approve DTOs and endpoints before enabling operational submission |
| Angular → API monthly/annual reports | Empty station arrays, placeholder metrics, local filter messages | Not connected | Not connected | Define authoritative read endpoints, aggregation and provenance |
| Angular dashboard → identity | Reads `localStorage.currentUser`; local-only logout | Local / placeholder | Not a verified auth session | Use authenticated session/profile and real Supabase sign-out |
| Flutter → API directory | `MetraApiClient.getStationDirectory()`; station directory screen calls it | Implemented in source | Not live-tested | Device test with HTTPS host and valid token |
| Flutter → API review | `getReviewQueue()`, `decideObservation()`; review screen calls both | Implemented in source | Not live-tested | Device test for queue, approve and return-for-correction |
| Flutter → API submit | Client method exists, but no observation-entry screen invoking it was found in inspected navigation tree | Client capability only; no screen integration evidenced | Not connected from inspected screen | Implement actual observation entry screen and contract tests |
| Flutter → reports/analytics | Home screen explicitly marks reports unavailable pending approved source | Not connected | Not connected | Implement read/report endpoints and screens |
| API → Supabase station catalogue | `SupabaseStationDirectoryService`, `station_catalogue` | Implemented in source | Readiness-gated; not live-tested here | Verify exact new-project projection, permissions and returned JSON |
| API → Supabase observation submission | RPC `metra_submit_observation` | Implemented in source | Not live-tested here | Migration/RPC contract + idempotency and rollback tests |
| API → Supabase decision/queue | RPC/service registrations in `Program.cs` | Partially evidenced | Not live-tested | Inspect each feature service, RPC and migration pair |
| API → JWT authorization | `Program.cs`, station permission endpoint extensions | Implemented in source | Not live-tested | Invalid token, wrong station, revoked assignment and role escalation tests |
| API → CORS | `Cors:AllowedOrigins` | Implemented in source | Blocked until host config | Positive exact-origin and negative unlisted-origin browser tests |
| API → production host | `backend/DEPLOYMENT.md`, `render.yaml` | Deployment recipe exists | Blocked; no host URL supplied | Provision only after owner approval; then health/readiness and TLS checks |
| R / Climatol → METRA | No executable/job/contract evidence found in inspected paths | Not evidenced | Not connected | Define versioned batch input/output contract and isolated worker |
| Paper images → electronic auditor | No upload/storage/auditor service evidence found in inspected paths | Not evidenced | Not connected | Define evidence storage, metadata, comparison and human adjudication contracts |
| API → reports/exports | No end-to-end report generation trace completed | Not evidenced by this audit | Unknown | Identify authoritative query/read endpoints and report provenance |

## Feature-level source inventory

See [CLIENT-DATA-SOURCE-INVENTORY.md](CLIENT-DATA-SOURCE-INVENTORY.md) for route-by-route Angular and Flutter screen classification, concrete file evidence and prioritized integration gaps.

## Contract baseline
- API prefix: `/api/v1`.
- Station directory: `GET /api/v1/stations?limit=&offset=&stationType=`.
- Submission: `POST /api/v1/stations/{stationId}/observations`; body fields `idempotencyKey`, `observationType`, `observedAt`, `payload`, `submit`.
- Review queue: `GET /api/v1/stations/{stationId}/observations?limit=`.
- Decision: `POST /api/v1/stations/{stationId}/observations/{observationId}/decision`; body `decision`, `note`.
- Station type values accepted by the API: `classic`, `automatic`, `synoptic`.
- Observation types accepted by submission guard: `daily`, `hourly`, `phenomenon`.
- Auth: bearer Supabase JWT; service-role key remains server-side.

## Priority order
**P0 — before live integration**
1. Configure and verify a real HTTPS API host and runtime client config; prove health and readiness.
2. Prove API auth and station-scoped authorization with positive and negative integration tests.
3. Verify Supabase schema/RPC contracts against the new project without applying unapproved migrations.
4. Prevent dashboard-local identity from being treated as authenticated authority; connect phenomena input/list.

**P1 — data correctness**
5. Freeze shared observation DTOs, UTC/time-zone semantics, enumerations and validation error codes.
6. Verify review state machine, audit trail and idempotency behavior end-to-end.
7. Reconcile missing station coordinates using authoritative evidence only.
8. Connect rainfall/climate/soil/agriculture and monthly/annual read/report features only after their contracts are approved.
9. Add Flutter observation entry and report-read screens before claiming parity.

**P2 — specialized integrations**
10. Define R/Climatol batch interface and reproducible worker runtime.
11. Define paper-image evidence ingestion and auditor result interface.
12. Complete reports/export integration and client parity.


## Contract cross-check update — 2026-11-11

Detailed evidence is recorded in [API-CONTRACT-CROSSCHECK.md](API-CONTRACT-CROSSCHECK.md).

| Contract edge | New finding | Severity / disposition |
|---|---|---|
| ASP.NET Core station catalogue → Flutter | Flutter requires non-null `local_station_code` and `name_en`; Angular contract permits null for both; API forwards the database projection without normalizing them | **P1 confirmed source-level DTO mismatch**; align Flutter nullability or formally constrain schema after owner review |
| Angular/Flutter observation submit → ASP.NET Core | Route, verb and camelCase request fields align with `ObservationSubmissionRequest` | Source-level match; runtime serialization/RPC response not tested |
| Client validation → submission endpoint | Daily/hourly/phenomena domain validation endpoints exist, but inspected clients do not call them; submission guard checks only generic shape/type/time/idempotency/size before RPC | **P0/P1 validation assurance gap**; prove RPC enforces all meteorological rules or centralize validation in server persistence path |
| Review queue → clients | Queue route, limit parameter and selected response fields align with Angular and Flutter models | Source-level match; schema/RPC behavior not tested |
| Decision → clients/API | Route, `decision` and `note` fields align; API checks station-specific permission and requires note for return | Source-level match; DB transition/audit behavior unverified |
| API → Supabase schema/RPC | RPC names and PostgREST projections are visible in C# services; exact migration signatures, nullability, grants and return shape not confirmed | Open until migration/RPC evidence and contract tests |

The station-directory nullability issue and validation-boundary gap are now explicit blockers in the cross-client contract review. No code or schema change was made.
