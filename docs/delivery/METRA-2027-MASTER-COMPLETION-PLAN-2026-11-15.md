# METRA 2027 — Master Completion and Delivery Plan

**Plan date:** 2026-11-15  
**Execution branch:** `work/metra-completion-roadmap-2026-11-15`  
**Baseline:** Flutter branch commit `f222fbaacb485a653b02b631629c75387a810840`  
**Related UI PR:** [#40](https://github.com/gfa437926-tech/metra2027/pull/40) — Draft, not merged  
**Status:** Execution plan and audited baseline; not a production-readiness declaration.

## 1. Non-negotiable project boundaries

1. Keep the legacy database and its station data untouched. No legacy imports, updates, deletes, or schema changes.
2. Do not apply migrations, seeds, RPC changes, or data writes to any hosted Supabase project without an explicit owner-approved change plan.
3. Treat the configured Supabase project as **unverified for this release** until its current identity, schema, ownership, and data classification are reconciled. Earlier repository evidence is inconsistent: a prior read-only report recorded 65 catalogue rows and 58,059 archive rows, so it must not be assumed empty.
4. Flutter is the current client priority. Angular work is deferred and must not be introduced into the Flutter completion branch.
5. Keep all new work on isolated feature branches and open Draft PRs. Do not merge to `main` or deploy without an explicit release decision.
6. Never represent a UI placeholder as a working scientific service. OCR, chart digitization, CLIMATOL execution, AI training/inference, and persistence require real backend implementations and validation.
7. Preserve raw observations and original source images. Derived or corrected values must be versioned, traceable to their source and algorithm, and subject to human approval.
8. Never place Supabase service-role credentials or other server secrets in Flutter, browser code, source control, or build-time client defines.

## 2. Audited baseline (2026-11-15)

| Area | Verified repository evidence | Current classification |
|---|---|---|
| Flutter client | `mobile/metra_mobile` includes operations screens and scientific workspaces | UI candidate |
| Flutter CI | Run `43663098749` completed successfully; `pub get`, analyze, and 44 tests passed | Verified at commit `f222fba` |
| Navigation | 13 destinations, adaptive horizontal navigation | Implemented in UI branch |
| Records workspace | Paper/mechanical archive, image review, instrument types, triple-source comparison surfaces | UI only; no live OCR/upload workflow |
| CLIMATOL workspace | Preparation, time series, breakpoint, reference station, corrected-series and report surfaces | UI only; no execution runtime |
| AI workspace | Dataset, annotation, experiment, evaluation, registry and monitoring surfaces | UI only; no training/inference runtime |
| .NET API | ASP.NET Core 10 API with JWT auth, station/observation/user feature areas, health/readiness, tests and Dockerfile | Partial backend exists |
| API feature gaps | Current feature folders are Observations, Stations and Users | Records/OCR, Homogenization and AI services not evidenced as implemented |
| Database assets | `database/{baseline,isolated,migrations,proposals,seeds,tests,transfer}` and `supabase/migrations` exist | Design and migration assets require reconciliation |
| Hosted database | Repository report `STAGE-C9.6` records existing catalogue/archive rows and no approved provisioning grants at inspection time | Not safe to assume empty or ready |
| Native mobile builds | Flutter source/package exists; Android/iOS runners are absent from the package inventory | Build prerequisite outstanding |
| Deployment | API deployment guidance and container workflow exist; no verified production deployment in this audit | Not deployed/verified |
| Angular | Present elsewhere in repository | Deferred; out of this execution scope |

### Evidence references

- [Flutter PR #40](https://github.com/gfa437926-tech/metra2027/pull/40)
- [Flutter release readiness](../../mobile/metra_mobile/RELEASE-READINESS.md)
- [Backend README](../../backend/README.md)
- [Live schema reconciliation report](STAGE-C9.6-LIVE-SCHEMA-AND-READINESS-RECONCILIATION.md)
- [Scientific field contract reconciliation](STAGE-C9.5-SCIENTIFIC-FIELD-CONTRACT-RECONCILIATION.md)

## 3. Execution stages and exit gates

### Stage 0 — Baseline and repository control

- [x] Confirm repository, default branch, permissions, Flutter branch and PR #40 state.
- [x] Verify the latest Flutter CI run and 44-test result.
- [x] Inventory the backend, database assets, Flutter package, and workflow files.
- [ ] Reconcile all open PRs and identify the authoritative backend/API baseline.
- [ ] Record current hosted-project identity and schema evidence through approved read-only access only.
- [ ] Produce a single source-of-truth component inventory.

**Exit gate:** every deliverable is classified as implemented, tested, deployed, blocked, or not started, with evidence links.

### Stage 1 — Flutter client completion

- [x] Existing operations and scientific workspaces are present in the Flutter UI branch.
- [x] Adaptive navigation and scientific-workspace widget tests are present.
- [ ] Complete screen-by-screen requirements traceability for all roles and workflows.
- [ ] Complete responsive layouts, accessibility, keyboard/focus, localization and RTL review.
- [ ] Replace any remaining static/demo-only operational screen behavior with typed repository/service contracts.
- [ ] Add loading, empty, offline, validation, permission-denied and retry states consistently.
- [ ] Add contract tests for every API-backed workflow.
- [ ] Generate Android/iOS runners in a controlled build workspace and validate platform configuration.
- [ ] Run full analyze, unit, widget, integration and device tests.

**Exit gate:** all agreed screens are traceable to requirements; no action falsely claims to save, upload, approve, digitize, train, or run analysis when its service is unavailable.

### Stage 2 — Domain model and database design (design first)

- [ ] Define bounded contexts: identity/access, authority/stations, observations, instrument records, quality review, homogenization, AI/ML, reports, audit and file assets.
- [ ] Produce a normalized ERD with ownership, cardinality, lifecycle and retention rules.
- [ ] Produce a complete data dictionary (table, column, type, nullability, default, constraints, indexes, sensitivity and provenance).
- [ ] Define immutable raw-source storage and append-only audit/version history.
- [ ] Define station/time/variable units, UTC handling, missing-value codes and scientific validation contracts.
- [ ] Define authorization matrix and least-privilege database roles.
- [ ] Create reproducible migrations and synthetic seeds for an isolated empty test database.
- [ ] Add migration-up, migration-down/rollback strategy where safe, and clean-rebuild tests.
- [ ] Compare the proposed design with current hosted schema without applying changes.

**Exit gate:** ERD, dictionary, security model, migration plan and scientific contracts are reviewed and approved before any hosted DDL or data write.

### Stage 3 — .NET backend completion

- [ ] Establish the approved API contract and versioning policy.
- [ ] Complete identity/session lifecycle, authorization policies and station/authority scoping.
- [ ] Complete observation create/edit/submit/review/archive flows with idempotency and concurrency controls.
- [ ] Implement secure file metadata, signed upload/download flow, validation, malware scanning and retention.
- [ ] Implement record-image and annotation APIs.
- [ ] Implement job orchestration and status APIs for OCR, CLIMATOL and AI workloads.
- [ ] Implement report/export APIs and audit/provenance endpoints.
- [ ] Add structured logging, correlation IDs, metrics, tracing, rate limits and health/readiness.
- [ ] Add unit, API, integration, authorization-isolation and failure-mode tests.
- [ ] Verify container build and dependency/security scanning.

**Exit gate:** API contracts are implemented, documented, tested, and pass cross-station/role isolation tests; secrets are server-side only.

### Stage 4 — Supabase and persistence integration

- [ ] Confirm exact target project reference and environment (development/staging/production).
- [ ] Perform read-only inventory and reconcile conflicting historical reports.
- [ ] Confirm whether existing data belongs to the new METRA design or a previous/other workload.
- [ ] Prepare isolated database from reviewed migrations and synthetic data.
- [ ] Validate RLS, grants, RPC security-definer search paths, atomic authorization and rollback.
- [ ] Obtain explicit approval for a narrowly scoped hosted change set.
- [ ] Apply only the approved change set to the intended new project and verify postconditions.
- [ ] Provision synthetic staging identities/roles through controlled workflows.
- [ ] Verify backups and point-in-time recovery capability.

**Exit gate:** schema fingerprint matches the approved design; RLS and grants pass negative tests; no legacy database was accessed or modified.

### Stage 5 — Operational meteorology and records digitization

- [ ] Complete hourly and daily observation contracts and resolve scientific range/time ambiguities with the scientific owner.
- [ ] Implement immutable paper/mechanical image ingestion and metadata.
- [ ] Implement instrument-specific calibration/scale configuration for Thermograph, Hygrograph, Barograph and Pluviograph.
- [ ] Implement OCR and chart-curve extraction as separate, measurable pipelines.
- [ ] Store source coordinates/regions, extracted values, confidence, model/version and reviewer corrections.
- [ ] Implement paper vs mechanical vs electronic comparison and discrepancy classification.
- [ ] Implement review, correction, approval, rejection and audit history.
- [ ] Validate extraction against expert-labelled ground truth.

**Exit gate:** a reviewer can trace every displayed value to a source image/record and extraction version; measured accuracy meets thresholds approved by the scientific owner.

### Stage 6 — CLIMATOL and climate homogenization

- [ ] Pin and document CLIMATOL/R runtime and dependency versions.
- [ ] Define input dataset contract, station metadata and reference-station selection.
- [ ] Implement isolated job execution, queue, cancellation, retry and resource limits.
- [ ] Persist job configuration, logs, diagnostics and exact input snapshot.
- [ ] Produce breakpoint candidates and diagnostic visualizations.
- [ ] Require expert review before corrections are accepted.
- [ ] Preserve original series and store corrected series as immutable versions with provenance.
- [ ] Implement monthly, seasonal, annual normals, indices, trends and export reports.
- [ ] Validate against reference datasets and reproducible expected outputs.

**Exit gate:** independent reruns on the same versioned inputs/configuration are reproducible; no corrected series overwrites raw observations.

### Stage 7 — AI/ML lifecycle

- [ ] Define dataset versioning, consent/rights, lineage and retention.
- [ ] Build annotation and adjudication workflows for images and extracted values.
- [ ] Split train/validation/test by station and time to prevent leakage.
- [ ] Implement reproducible experiment configuration and compute-job orchestration.
- [ ] Implement model evaluation, calibration, confidence thresholds and error analysis.
- [ ] Create model registry with artifacts, hashes, training data lineage and approval status.
- [ ] Deploy inference behind an authenticated API with rate limits and monitoring.
- [ ] Monitor drift, quality, latency and rollback readiness.
- [ ] Require human approval for scientific records until a separately approved automation policy exists.

**Exit gate:** each production model has reproducible lineage, independent evaluation, an approved threshold, monitoring and rollback.

### Stage 8 — Security, reliability and release engineering

- [ ] Threat model identity, data access, image upload, processing workers and model endpoints.
- [ ] Run SAST, dependency scanning, secret scanning, DAST and penetration testing.
- [ ] Verify encryption in transit/at rest, key rotation and least privilege.
- [ ] Test tenant/station/authority isolation, account lifecycle and session revocation.
- [ ] Run load, soak, resilience, backup restore and disaster recovery exercises.
- [ ] Create staging release and signed Android APK/AAB.
- [ ] Create signed iOS archive on macOS/Xcode when iOS distribution is in scope.
- [ ] Run real-device acceptance and offline/reconnect scenarios.
- [ ] Verify production API health, readiness, alerting and rollback.

**Exit gate:** all critical/high security findings are resolved or formally risk-accepted; release artifacts are signed and tested.

### Stage 9 — Operational handover

- [ ] Publish architecture, API, database and scientific method documentation.
- [ ] Publish administrator, station operator, reviewer and analyst user guides.
- [ ] Deliver source, build instructions, signed binaries and release checksums.
- [ ] Deliver migration/restore procedures and backup schedule.
- [ ] Deliver monitoring dashboards, alert ownership and incident runbooks.
- [ ] Train administrators and key scientific reviewers.
- [ ] Complete final acceptance record and known-limitations register.

**Exit gate:** an independent operator can install, configure, restore, operate and troubleshoot the system using the handover package.

## 4. Workstream order and dependencies

1. Flutter UI traceability and backend contract work can proceed in parallel.
2. Domain/ERD design must precede production schema changes.
3. API implementation can proceed against isolated test schema and synthetic data.
4. Upload/OCR work depends on secure file storage and record provenance.
5. CLIMATOL execution depends on approved climate data contracts and isolated worker orchestration.
6. AI training depends on versioned datasets, annotations and leakage-safe splits.
7. Production rollout depends on security, scientific validation, signed builds and operational readiness.

## 5. Current blockers and owner decisions

| Blocker | Why it matters | Safe next action |
|---|---|---|
| Hosted project data-state ambiguity | Existing report says project contains records; cannot assume empty | Reconcile read-only inventory and ownership before any DDL |
| Scientific field/time contract ambiguities | Incorrect ranges or observation-time mapping corrupt scientific records | Keep write path gated until signed scientific decision |
| Missing OCR/CLIMATOL/AI execution services | UI cannot perform scientific processing alone | Implement isolated workers and APIs with reference tests |
| No native platform runners in Flutter package | No verified APK/AAB/iOS artifact | Generate runners in a feature branch/build workspace |
| No verified production deployment | CI success does not prove a live service | Deploy to isolated staging after environment approval |
| Signing credentials and distribution ownership | Required for distributable mobile builds | Configure secrets in platform signing environment; never commit them |

## 6. Definition of done

METRA 2027 is complete only when every stage exit gate is evidenced, the required mobile/web clients are built and signed, .NET services and persistence are deployed to the approved environment, scientific services pass independent validation, security and recovery tests pass, and the operational handover is accepted.

A green CI run, a merged PR, or a visually complete UI alone does not satisfy this definition.
