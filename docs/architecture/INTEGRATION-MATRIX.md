# METRA 2027 — Integration and contract matrix

**Audit date:** 2026-11-11 · **Baseline:** `main` · **Status vocabulary:** Implemented in source / Partially evidenced / Not evidenced / Blocked pending environment.

| Producer → Consumer | Contract / evidence inspected | Source-level status | Runtime status | Gap / next proof |
|---|---|---|---|---|
| Angular → Supabase Auth | `SupabaseAuthService`, `SupabaseAuthService.getAccessToken()`, app config | Implemented in source | Not live-tested | Verify login, refresh, expiry, sign-out and revocation in isolated env |
| Flutter → Supabase Auth | `main.dart`, `core/auth/metra_auth.dart` referenced by main | Partially evidenced | Not live-tested | Inspect auth implementation and secure storage/session lifecycle |
| Angular → API station directory | `ObservationApiService.getStations()`, GET `/api/v1/stations` | Implemented in source | Blocked/unverified without deployed API config | Authenticated browser request + response contract test |
| Angular → API submit | `submitObservation()`, POST `/api/v1/stations/{stationId}/observations` | Implemented in source | Not live-tested | Verify each report screen invokes service and payload is domain-complete |
| Angular → API review | `getReviewQueue()`, `decide()` | Implemented in source | Not live-tested | Test station-scoped reviewer authorization and state transitions |
| Flutter → API directory | `MetraApiClient.getStationDirectory()` | Implemented in source | Not live-tested | Device test with HTTPS host and valid token |
| Flutter → API submit | `MetraApiClient.submitObservation()` | Implemented in source | Not live-tested | Verify all mobile entry screens use it; payload schema contract test |
| Flutter → API review | `getReviewQueue()`, `decideObservation()` | Implemented in source | Not live-tested | Device test for queue, approve and return-for-correction |
| API → Supabase station catalogue | `SupabaseStationDirectoryService`, `station_catalogue` | Implemented in source | Readiness-gated; not live-tested here | Verify exact new-project projection, permissions and returned JSON |
| API → Supabase observation submission | RPC `metra_submit_observation` | Implemented in source | Not live-tested here | Migration/RPC contract + idempotency and rollback tests |
| API → Supabase decision/queue | RPC/service registrations in `Program.cs` | Partially evidenced | Not live-tested | Inspect each feature service, RPC and migration pair |
| API → JWT authorization | `Program.cs`, station permission endpoint extensions | Implemented in source | Not live-tested | Invalid token, wrong station, revoked assignment and role escalation tests |
| API → CORS | `Cors:AllowedOrigins` | Implemented in source | Blocked until host config | Positive exact-origin and negative unlisted-origin browser tests |
| API → production host | `backend/DEPLOYMENT.md`, `render.yaml` | Deployment recipe exists | Blocked; no host URL supplied | Provision only after owner approval; then health/readiness and TLS checks |
| Angular feature pages → API coverage | Route list includes reports, climate, agriculture, soil, users, workflow | Mixed / unverified | Unknown | Trace each feature's data source and classify live/local/mock |
| Flutter feature parity → API | One API client with station/observation/review operations | Partial | Unknown | Inventory every screen and bind each to shared contracts |
| R / Climatol → METRA | No executable/job/contract evidence found in inspected paths | Not evidenced | Not connected | Define versioned batch input/output contract and isolated worker |
| Paper images → electronic auditor | No upload/storage/auditor service evidence found in inspected paths | Not evidenced | Not connected | Define evidence storage, metadata, comparison and human adjudication contracts |
| API → reports/exports | No end-to-end report generation trace completed | Not evidenced by this audit | Unknown | Identify authoritative query/read endpoints and report provenance |

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
4. Trace every Angular/Flutter form to an API call or explicitly label it local-only/demo.

**P1 — data correctness**
5. Freeze shared observation DTOs, UTC/time-zone semantics, enumerations and validation error codes.
6. Verify review state machine, audit trail and idempotency behavior end-to-end.
7. Reconcile missing station coordinates using authoritative evidence only.

**P2 — specialized integrations**
8. Define R/Climatol batch interface and reproducible worker runtime.
9. Define paper-image evidence ingestion and auditor result interface.
10. Complete reports/export integration and client parity.
