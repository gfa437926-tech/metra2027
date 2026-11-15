# METRA 2027 — Flutter / .NET API Integration Matrix

**Audit date:** 2026-11-15  
**Client baseline:** `work/metra-flutter-release-2026-11-15`  
**API baseline:** same repository branch  
**Status:** Read-only contract audit; no runtime or database changes.

## 1. Purpose

This matrix records the current Flutter client methods and ASP.NET Core route surface, distinguishes implemented transport contracts from complete business workflows, and identifies missing server capabilities for the records, CLIMATOL and AI workspaces.

A route being present does not prove that its hosted database dependency is configured, that a complete end-to-end workflow has been accepted, or that the feature is deployed.

## 2. Verified API surface

All routes below are registered by `backend/Metra.Api/Program.cs`. Unless explicitly stated otherwise, the API has a fallback authorization policy requiring an authenticated user. Server-to-Supabase requests use the server-side service credential; it must never be shipped to Flutter.

| Domain | Verified route(s) | Flutter client method(s) | Audit status |
|---|---|---|---|
| Health/readiness | `GET /api/v1/health`; `GET /api/v1/ready` | Health/readiness client coverage to be reconciled | Routes exist; readiness probes server configuration and required RPC/read paths |
| Station directory | `GET /api/v1/stations` | `getStationDirectory`, `getAllStationDirectory` | Client and API contract present |
| Observation validation | `POST /api/v1/observations/hourly/validate`; `/daily/validate`; `/phenomena/validate` | Client call sites to be reconciled | Server validation routes present |
| Observation submission | `POST /api/v1/stations/{stationId}/observations` | `submitObservation` | API and client contract present; persistence depends on server configuration and database RPC |
| Observation queue | `GET /api/v1/stations/{stationId}/observations` | `getReviewQueue` | API and client contract present; actor-bound station access |
| Observation decision | `POST /api/v1/stations/{stationId}/observations/{observationId}/decision` | `decideObservation` | API and client contract present |
| Observation archive | `GET /api/v1/stations/{stationId}/observation-archive`; `GET /api/v1/stations/{stationId}/observation-archive/{observationId}` | `getObservationArchive`, `getObservationArchiveDetail` | API and client contract present |
| Station user directory | `GET /api/v1/stations/{stationId}/users` | `getStationUsers` | API and client contract present |
| Station audit | `GET /api/v1/stations/{stationId}/audit-log` | `getStationAuditLog` | API and client contract present |
| Station assignments | `GET /assignable-roles`; `POST /assignments`; decision and revoke routes under station | Client method coverage requires reconciliation | API routes present |
| Registration | `GET /api/v1/registration-roles`; `GET /api/v1/account/registration-status`; `POST /api/v1/registration-requests` | `getRegistrationRoles`, `getMyRegistrationStatus`; submission call site to reconcile | API and partial client contract present |
| Registration review | Station-scoped registration/system-registration queue, decision and audit routes | Client call sites to reconcile | API routes present |
| Authority access | Authority list, memberships, permission grants, access queue/audit, role and permission option routes | Authority client methods present | API and client contract present |

### Exact Flutter client methods verified

The client file `mobile/metra_mobile/lib/core/api/metra_api_client.dart` contains:

- `getStationDirectory`, `getAllStationDirectory`
- `getStationAuditLog`, `getReviewQueue`
- `getObservationArchive`, `getObservationArchiveDetail`
- `decideObservation`, `submitObservation`
- `getStationUsers`
- `getRegistrationRoles`, `getMyRegistrationStatus`
- `getAuthorities`, `getAuthorityAccessQueue`, `getAuthorityAccessAudit`
- `getAuthorityMembershipRoles`, `getAuthorityPermissionOptions`

The client contains additional request helpers and methods beyond this selected list; the complete method-to-widget traceability audit remains open.

## 3. Critical capability gaps

The following are not evidenced as implemented, registered production API areas in the audited `.NET Program.cs` route map. Treat them as missing server capabilities until source and integration tests prove otherwise.

| Capability | Required API contract | Required persistence / processing | Priority |
|---|---|---|---|
| Instrument/paper record catalogue | Create/list/detail/update metadata and lifecycle transitions | Versioned record metadata, station scope, instrument type, observation period | P0 |
| Secure image ingestion | Create upload intent, finalize upload, list/download metadata | Private object storage, checksum, MIME/size validation, malware scanning, retention | P0 |
| Image annotations | Read/write regions, points, labels and reviewer corrections | Immutable annotation versions and actor audit | P0 |
| OCR job lifecycle | Submit job, status, result, retry/cancel | Isolated worker, queue, model/version, confidence and source coordinates | P1 |
| Mechanical chart digitization | Calibrated chart setup, curve extraction, candidate values | Instrument-specific calibration, coordinate-to-value transform, QC flags | P1 |
| Triple-source comparison | Compare paper/mechanical/electronic readings for variable and time window | Source lineage, matching tolerances, discrepancy classifications, reviewer decisions | P1 |
| CLIMATOL jobs | Validate input, create/run/cancel job, status, diagnostics and outputs | Pinned R/CLIMATOL worker, job queue, immutable input snapshot and output versions | P1 |
| Homogenization review | Review breakpoints, accept/reject, approve corrections | Expert decisions, provenance, original and adjusted series kept separately | P1 |
| Climate products | Normals, indices, trends, monthly/seasonal/annual products and export | Versioned calculation definitions and reproducible reports | P2 |
| AI datasets and annotation | Dataset versions, samples, labels, adjudication and splits | Rights/retention metadata, lineage, station/time leakage-safe partitions | P1 |
| AI experiments/training | Create experiment, queue training, progress, logs and artifacts | Isolated compute worker, pinned environment, reproducible configs | P1 |
| Model registry/inference | Register/evaluate/approve/deploy/rollback and authenticated inference | Artifact hashes, evaluation metrics, monitoring, rollback | P1 |
| Unified provenance/audit | Query source-to-result lineage across all scientific workflows | Append-only event history and immutable artifact references | P0 |

P0 = prerequisite for safe operational integration; P1 = core scientific workflow; P2 = downstream products and reporting.

## 4. Required API design rules

1. Every station-scoped endpoint derives the actor identity from the validated JWT; never trust a client-supplied actor/user ID.
2. Every write supports an idempotency strategy and explicit concurrency/version semantics.
3. Every file is private by default. Uploads use short-lived signed intents and server-side finalization checks.
4. Original images and raw observations are immutable. Corrections, annotations, OCR candidates and adjusted climate series are new versioned records.
5. Every scientific output records source snapshot, algorithm/runtime version, configuration, job ID, timestamp and reviewer/approval state.
6. Long-running OCR, chart digitization, CLIMATOL and ML training run asynchronously. API requests create jobs and return job identifiers; they do not hold open HTTP requests for the duration of scientific computation.
7. Job status includes queued/running/succeeded/failed/cancelled, safe error codes, retryability and timestamps. Do not expose secrets, raw stack traces or internal object-store paths.
8. AI predictions and OCR candidates remain advisory until the authorized human review policy explicitly accepts them.
9. Authorization is enforced server-side for each object and every job/status/result endpoint, not only in Flutter navigation.
10. All API contracts have schema tests, negative authorization tests, idempotency tests and failure/retry tests.

## 5. Implementation sequence

### Package A — Complete existing operational contracts

- [ ] Build a route-to-client-to-screen traceability inventory for every Flutter screen.
- [ ] Add missing client methods only where the backend route and request/response contract are verified.
- [ ] Add integration tests for station directory, validation, submit, queue, decision, archive, station users and audit.
- [ ] Verify authorization denial across stations and roles using isolated test fixtures.
- [ ] Verify health vs readiness behavior and dependency outage handling.

### Package B — Records and digitization contracts

- [ ] Define records and instrument metadata DTOs.
- [ ] Define private object-storage upload/finalization contract.
- [ ] Define annotation schema and version lifecycle.
- [ ] Define OCR and chart-digitization job contracts.
- [ ] Define triple-source matching and discrepancy DTOs.
- [ ] Add isolated persistence migrations and worker tests only after the schema design review gate.

### Package C — Climate homogenization contracts

- [ ] Define time-series import and validation contracts.
- [ ] Define CLIMATOL job configuration, status, diagnostics and artifact contracts.
- [ ] Define breakpoint review and correction approval workflow.
- [ ] Define immutable raw/adjusted series provenance.
- [ ] Add deterministic reference fixtures and reproducibility tests.

### Package D — AI lifecycle contracts

- [ ] Define dataset/sample/annotation version contracts.
- [ ] Define station/time-aware split contract and leakage checks.
- [ ] Define experiment, training job and artifact contracts.
- [ ] Define evaluation, model approval, registry and rollback contracts.
- [ ] Define authenticated inference and drift monitoring contracts.

## 6. Release gates

- No feature is marked integrated until Flutter, API, persistence/worker, authorization and automated tests all pass together.
- No database migration is applied to a hosted project until target identity and current schema are reconciled and the exact change set is explicitly approved.
- No legacy database or legacy station dataset is used as an input.
- No production claim is made for OCR, CLIMATOL or AI until real services produce independently validated results.
- No APK/AAB/iOS release is claimed until a real signed build and device acceptance evidence exist.

## 7. Audit limitations

This document is a source-level route/client audit from the named branch. It is not a live environment test, a schema approval, a security certification, or a production deployment report. Items labelled “requires reconciliation” are deliberately left open rather than inferred from UI labels.
