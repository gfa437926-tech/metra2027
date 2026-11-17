# C9.2 — Atomic Actor-Bound Station Read Design

**Baseline:** `3d2958cd194af571a41abecefa6923494adb2d11`  
**Status:** design proposal only — implementation and concurrency verification remain open.  
**Hosted Supabase:** untouched.  
**Release decision:** not Production Ready.

## 1. Confirmed source-level gap

The following endpoint flows are split across two requests to the database:

| Endpoint | API-side authorization | Subsequent privileged read |
|---|---|---|
| `GET /api/v1/stations/{stationId}/observations` | `IStationAuthorizationService.HasStationPermissionAsync` for review permissions | `SupabaseObservationQueueService.GetSubmittedAsync` reads `metra_observations` with service-role |
| `GET /api/v1/stations/{stationId}/users` | `RequireStationPermission("users.station.view")` endpoint filter | `get_station_user_directory(p_station_id,p_limit)` service-role RPC |
| `GET /api/v1/stations/{stationId}/audit-log` | `RequireStationPermission("users.station.view")` endpoint filter | `get_station_audit_log(p_station_id,p_limit)` service-role RPC |

The current directory and audit RPCs accept station and limit only. They do not receive or verify the authenticated actor. The API filter verifies the actor before the separate privileged read. A permission revocation or assignment change can therefore race with the later read.

This is a TOCTOU design weakness. The review does not claim a demonstrated production exploit; it establishes that the current design does not make the authorization decision atomic with the privileged read.

## 2. Required API contract

Replace the split authorization/read sequence with narrowly scoped RPCs. Each RPC must accept:
- `p_actor_user_id uuid` — extracted exclusively from the validated JWT `sub` claim by the API; never from request body, query, or route.
- `p_station_id uuid` — route station identifier.
- `p_limit integer` — strictly bounded by the database function as well as API validation.

The RPC must return only the projection required by its endpoint:
- submitted observation review queue;
- station staff directory;
- station audit projection.

The service-role key remains server-side. Browser roles receive no direct execute permission.

## 3. Database atomicity requirements

A simple call to the existing `metra_user_has_station_permission` followed by a separate service-role read is not sufficient.

The replacement function must:
1. Run as a single database transaction/RPC and be `SECURITY DEFINER` with a fixed, safe `search_path`.
2. Validate non-null actor/station IDs and bounded limits.
3. Establish the exact-station permission predicate: active account, active country/authority, approved operational non-demo station, current approved membership, current approved assignment to the exact station, active role and role-permission mapping, and approved non-revoked time-valid individual grant.
4. Ensure authorization-relevant rows cannot be concurrently revoked or changed between the authorization decision and data projection. The implementation must use a reviewed row-lock/transaction strategy with deterministic lock ordering, or an equivalent database-enforced serialization mechanism. Merely moving the old predicate and SELECT into two sequential API calls does not close the race.
5. Return the data only after authorization is established inside that same RPC. Unauthorized and cross-station requests return no protected rows.
6. Apply a stable ordering and a hard maximum limit. Do not return secrets, credentials, authentication tokens, or unnecessary personal data.
7. Fail closed on missing schema/function, malformed result, database error, or timeout.

### Concurrency semantics to prove

The implementation must define the linearization point. If a revocation commits before the RPC acquires the authorization locks, the read must be denied. If the read has already acquired its authorization locks, a concurrent revocation must wait until the read transaction completes; no read may proceed based on a stale API-side authorization result.

Lock all authorization facts whose mutation can change the predicate (account state, station/authority/country active state, membership, station assignment, role state/mapping, and matching individual grants). Use deterministic ordering and test for deadlocks. Do not assume that locking only the grant row is sufficient.

## 4. Implementation and test sequence

1. Add isolated-schema definitions for actor-bound read RPCs; do not alter existing hosted functions.
2. Add synthetic fixtures for two stations, same-authority and cross-authority users, valid and invalid assignments, grants, and role mappings.
3. Add positive tests for an authorized actor reading only the permitted station.
4. Add negative tests for missing/expired/revoked grants, expired/unapproved assignments, inactive accounts, inactive stations/authorities/countries, disabled roles, absent role mapping, empty actor, and station B access using station A's grant.
5. Add two-session PostgreSQL concurrency tests:
   - revoke grant before read lock acquisition => denied;
   - revoke assignment before read lock acquisition => denied;
   - concurrent revoke after read locks acquired => revocation blocks until read completes;
   - repeated parallel grant/revoke/read operations => no unauthorized rows and no unexpected deadlocks.
6. Add API tests proving the actor is derived from JWT `sub`, and caller-supplied actor IDs are ignored/rejected.
7. Replace the three split API flows only after the isolated SQL tests and API tests pass.
8. Run all Backend, Flutter, and database CI on the resulting commit.

## 5. Separate Flutter submission mismatch

The hourly and daily observation screens currently save only a local in-session draft and explicitly say that production submission is unavailable. The readiness registry classifies `observationSubmit` as `liveApi`. These states conflict.

Required work:
- distinguish local draft readiness from live API submission readiness;
- keep the production submit action disabled until the scientific field contract and backend endpoint are approved;
- add tests that prevent the UI from showing a successful server submission when no API request was made;
- obtain authoritative units, precision, null/missing-value conventions, validation, and time-zone/observation-time rules before enabling live writes.

## 6. Scope and approval boundary

This document is a design specification only:
- no application source code changed;
- no SQL migration or RPC was applied;
- no hosted Supabase schema, policies, grants, or data changed;
- no old database was accessed or changed;
- no PR merge or deployment performed.

A later implementation must first target the isolated PostgreSQL test environment. Hosted SQL requires separate explicit approval after schema review.

## 7. Acceptance decision

**C9.2 design recorded; implementation not yet complete.** The three privileged read paths and the Flutter readiness mismatch remain release blockers until code, isolated concurrency tests, API tests, and CI demonstrate closure.
