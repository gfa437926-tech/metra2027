# METRA 2027 — Stage A Baseline: Backend, Database & Integration

**Date:** 2026-11-11  
**Branch for this phase:** `work/backend-db-integration-phase`  
**Derived from:** `work/flutter-complete-from-pr34` @ `c459b86542d54e3feea3258d719965e2a9530aa8`  
**PR #34 head (Flutter base):** `dd377081f7f211d3c15e5ca1db2cf8e551fda8e6`

## 1. Scope boundaries (mandatory)

| Rule | Status |
|------|--------|
| Work only in gfa437926-tech/metra2027 | Enforced |
| No METRA OLD / legacy DB writes | Enforced |
| No new Flutter project / no flutter create | Enforced |
| Flutter path remains `mobile/metra_mobile/` | Enforced |
| Angular out of scope for this entire phase | Enforced — zero Angular changes |
| No merge without explicit approval | Enforced |
| No writes / migrations / RLS / grants on hosted Supabase | Enforced |
| Isolated PostgreSQL only for DB tests | Enforced |
| No invented scientific validation rules | Enforced |

## 2. Repository reality (inspected)

### Flutter (already expanded in prior work branch)
- Path: `mobile/metra_mobile/`
- Screens: Home, Stations, Forecast, Hourly entry, Daily entry, Review, Electronic audit, Reports/Archive, AI, Climatol, Users, Settings
- API client: `lib/core/api/metra_api_client.dart` (queue, archive, stations, auth-related models)
- Tests present; Flutter SDK not available in this sandbox for live analyze/test

### .NET Backend (`backend/Metra.Api/`)
**Present and structured:**
- JWT Bearer auth against Supabase Auth authority
- Bounded HttpClient timeouts (8s) for all Supabase-backed services
- Features:
  - Stations: directory, catalogue review
  - Users: registration submission/review, station assignment, station user directory, station audit, authority access lifecycle
  - Observations: submission, validation endpoints, queue, decision
- Domain validators: Hourly, Daily, WeatherPhenomenon, ObservationAuthorizationPolicy, ObservationWorkflow
- Security: `IStationAuthorizationService` + station-scoped endpoint extensions

**Mapped routes (sample of existing):**
- Health / ready
- `/api/v1/stations`, station review, station users, station audit-log
- Registration request/status/roles + station/system registration decisions
- Station assignments (create/decision/revoke)
- Authority memberships & permission-grants lifecycle
- Observation queue + decision
- `/hourly/validate`, `/daily/validate`, `/phenomena/validate`

### Database
- `database/migrations/`: 27 SQL migrations (station permissions, registration, assignment, audit, authority grants, observation submission/decision, etc.)
- `supabase/migrations/`: 5 files (operational observation submission, deny client access, indexes, review decision, null hardening)
- `database/tests/`: shell contract verifiers for station permission RPCs, registration, assignment, authority, etc.
- Hosted project referenced in docs: `https://tbdnklyxjvbrilvnwgmq.supabase.co` — **must not be written to in this phase**

### Security docs
- `docs/security/role-permission-matrix.md` — conservative role→permission allow-list
- `docs/security/authority-scope-authorization.md` — membership + individual grants + audit immutability
- Archive permission scope document: **not found under exact name** `OBSERVATION-ARCHIVE-READ-PERMISSION-SCOPE.md` in current tree; must be located or created before granting archive read

### CI
- `client-ci.yml`: Angular + Flutter (`mobile/metra_mobile`)
- `backend-ci.yml`: restore/build/test + multiple `database/tests/verify_*.sh` contracts + container build

## 3. What is already working (code-level, not production claim)

- Station-scoped authorization service pattern
- Observation submit/queue/decision endpoints skeleton
- Registration two-stage review endpoints
- Station assignment + audit log read model
- Authority membership & permission-grant lifecycle (migrations 020–022)
- Domain validators for hourly/daily/phenomena (structure present; scientific bounds must not be invented)
- Append-only audit protection pattern (trigger reject update/delete)

## 4. Critical gaps (honest)

1. **Archive read permission scope** not fully closed (station-only vs authority-wide grant). Negative tests for cross-station archive inside same authority required.
2. **Hosted Supabase** has no real Auth users / grants yet (per authority doc) → real-user authorization tests outstanding.
3. **Scientific field bounds** for hourly/daily still need authoritative source; validators exist but must not invent ranges.
4. **Flutter ↔ API binding** for new UI screens (hourly/daily entry, electronic audit, users, AI, Climatol) still mostly mock/local.
5. **OpenAPI/Swagger** not confirmed as complete, versioned contract published for Flutter.
6. **Electronic audit** independent of station catalogue audit — UI exists; full backend projection may be incomplete.
7. **Forecast / AI / Climatol** — no production engines; UI correctly refuses fake results.
8. **E2E cycle** (login → station → submit → review → approve → report → archive with explicit grant) not proven end-to-end in this environment.
9. **Angular** present in repo but **out of scope** — leave untouched.

## 5. Prioritized remaining work order (Stages B–G)

| Stage | Focus | Gate before next |
|-------|--------|------------------|
| B | Complete Domain/.NET endpoints still missing for Flutter screens; document OpenAPI | No invented science; contracts reviewed |
| C | Isolated PostgreSQL migration test plan + proposed schema deltas (no hosted apply) | Written proposal + isolated test results |
| D | Archive permission scope decision + negative authz tests | Explicit human approval of scope |
| E | Wire Flutter client to real endpoints; remove mocks only when service passes tests | Per-service readiness |
| F | Full workflow + failure-path tests | Documented run results |
| G | Delivery report, PR links, residual risks | No merge without approval |

## 6. Immediate decisions required from you

1. **Archive read scope**: station-scoped only, or authority-wide grant allowed? (Recommend: station-scoped explicit grant only, until proven otherwise.)
2. Approval to add/extend OpenAPI document in-repo from existing endpoints.
3. Approval path for any new migration files (local + isolated PG only; never hosted without you).

## 7. Commit / branch state for Stage A

- Baseline document only in this Stage A commit.
- No backend behavior change yet.
- No DB change.
- No Angular change.
- No hosted Supabase change.

