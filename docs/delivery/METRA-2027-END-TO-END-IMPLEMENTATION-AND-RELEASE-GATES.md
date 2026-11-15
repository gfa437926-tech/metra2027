# METRA 2027 — End-to-end implementation and release gates

**Status:** execution baseline, not a declaration of production completion.
**Scope:** Flutter client, .NET API, private recorder evidence pipeline, scientific processing, CI/CD and release operations. Angular remains deferred.

## Delivery principles
1. Preserve the legacy database and its station records. No legacy import or mutation is part of this release.
2. Build the new scientific model as a clean domain, using only the newly supplied station catalogue after its ownership and source are verified.
3. Never apply DDL, migrations, seed data or hosted Supabase writes before explicit approval of the ERD, dictionary, constraints and migration plan.
4. Keep service-role credentials, storage credentials, scanner credentials and AI provider keys server-side.
5. Every scientific result must be reproducible and linked to immutable inputs, software/model version, parameters, actor and review decision.
6. No image, OCR candidate, AI prediction, homogenization output or comparison value becomes an approved observation without the configured human approval process.
7. A screen, DTO, interface, unit test or green CI run is not a deployed service.

## Work packages and exit criteria

### WP0 — Baseline and branch integrity
- Keep PR #48 and its stacked prerequisites reviewable; do not merge automatically.
- Record commit SHAs and CI run IDs.
- Require Flutter analyze/test and backend build/domain/integration tests.
- Resolve all analyzer errors and test failures before adding new feature behavior.
**Exit:** required CI green on the exact head commit; no unresolved merge conflicts.

### WP1 — Domain model and database approval (blocked gate)
- Review METRA-NEW-SCIENTIFIC-DATA-MODEL-ERD-DICTIONARY-2026-11-15.md.
- Review tenancy, station/instrument deployments, source provenance, immutable evidence, adjustment versions, AI dataset snapshots and audit events.
- Review retention, soft-delete/legal-hold policy, uniqueness, foreign keys, check constraints, indexes, row-level access model.
- Produce migration ordering, rollback strategy, seed policy and disposable-database rebuild proof.
- Obtain explicit approval before any executable migration or hosted schema change.
**Exit:** signed-off ERD/dictionary and migration plan; legacy database unchanged.

### WP2 — .NET application services and authorization
- Implement DTOs, application-service interfaces, endpoint validation and ProblemDetails errors.
- Derive actor and authority from validated JWT and active membership; ignore client-supplied actor/authority IDs.
- Enforce authority, station assignment, resource scope and action permission on every request.
- Use idempotency keys for creation and job submission; use ETags/version checks for decisions.
- Add rate limits, request-size limits, bounded dependency timeouts and audit events.
- Keep feature flags disabled until schema, service and integration tests are deployed.
**Exit:** API contract tests and authorization matrix pass; cross-authority and cross-station denial tests pass.

### WP3 — Private evidence storage and quarantine
- Select private object storage, encryption/key ownership, region, lifecycle, backup and disaster recovery.
- Issue one-use, short-lived upload intents bound to actor, capture, object key, max bytes, media policy and SHA-256.
- Write untrusted bytes only to quarantine; disable public access and normal preview/download paths.
- Verify actual byte count, signature, MIME, SHA-256, image dimensions and decode behavior server-side.
- Scan with a maintained malware/content scanner. Timeout/unavailable/unknown verdict remains quarantined.
- Promote only after all checks and server authorization pass; preserve original bytes and immutable evidence metadata.
- Add expiry cleanup, retry/dead-letter handling, legal hold and retention controls.
**Exit:** malicious, oversized, forged, replayed, cross-tenant and expired uploads are denied; clean uploads become reviewable only after the complete gate.

### WP4 — OCR and recorder chart digitization
- Create isolated, versioned processing workers with least-privilege read access to accepted evidence.
- Support Thermograph, Hygrograph, Barograph and Pluviograph profiles separately.
- Capture crop/rotation/deskew, chart calibration, axis/time mapping, curve segmentation and OCR candidates.
- Return candidate value, unit, timestamp, pixel/trace geometry, confidence, algorithm version and source asset ID.
- Keep raw candidate, human correction and approved value as separate records.
- Use representative station/time splits and maintain a labelled benchmark dataset.
**Exit:** benchmarked accuracy by instrument family and variable; reviewer can accept/reject/correct; provenance is queryable.

### WP5 — Three-source and ground-truth comparison
- Align paper transcription, mechanical trace and electronic observation by station, variable, timestamp, timezone and unit.
- Never interpolate or fabricate a missing source without explicit documented policy.
- Record conversion rules, tolerances, quality flags, source IDs and algorithm versions.
- Provide image-versus-ground-truth and three-source discrepancy reports.
- Keep source values immutable; decisions create separate resolution records.
**Exit:** reproducible comparison results, independently reviewed reference values, auditable discrepancy decisions.

### WP6 — CLIMATOL / homogeneity processing
- Pin source series, reference stations, period, quality rules, software image digest and parameters.
- Run processing asynchronously in isolated workers.
- Detect candidate breakpoints and retain evidence/statistics for each candidate.
- Require climate-scientist review; create a new immutable adjusted-series version rather than modifying source series.
- Apply dual control for approval/publication.
- Generate monthly, seasonal, annual normals, trends, indices and reports only from pinned approved inputs.
**Exit:** reproducibility test reruns identical input/config and matches expected outputs; raw and adjusted series remain distinguishable.

### WP7 — AI dataset, training and inference governance
- Build immutable dataset snapshots with sample hashes and lineage.
- Split by station and time to prevent leakage; never train on the test partition.
- Version annotations and corrections independently from original evidence.
- Record code/container digest, model architecture, parameters, random seed, data snapshot and metrics.
- Evaluate on protected holdout; report CER/WER, MAE/RMSE, precision/recall, F1 and calibration where applicable.
- Require independent approval before model deployment.
- Inference returns candidates only; never auto-approve official observations.
- Monitor drift, false positives, station-specific performance and rollback readiness.
**Exit:** reproducible training/evaluation, leakage tests pass, model approval and rollback are operational.

### WP8 — Flutter integration and accessibility
- Replace local-only drafts with typed API repositories and explicit loading/empty/error/retry states.
- Use short-lived transfer authorization for uploads; never store service credentials in the app.
- Specify encrypted offline draft persistence, expiry and conflict behavior before enabling it.
- Verify RTL, keyboard navigation, screen readers, tablet/desktop breakpoints and slow-network behavior.
- Provide clear pending/reviewed/approved/rejected status and prevent double submission.
**Exit:** Flutter integration tests against staging pass for every role and workflow.

### WP9 — Deployment, observability and recovery
- Separate dev, test, staging and production environments and credentials.
- Use immutable container images, SBOM, vulnerability scanning, signed artifacts and protected deployment approvals.
- Keep secrets in deployment secret manager; rotate credentials and document emergency revocation.
- Configure structured logs, traces, metrics, alerts, audit retention and privacy-safe redaction.
- Test backup restoration, storage recovery, worker retry, queue poison-message handling and incident response.
- Run load, soak, dependency-failure and disaster-recovery tests.
**Exit:** staging operational acceptance, security review, restore drill and monitored rollback.

### WP10 — Release and handover
- Add Android/iOS native runners, app identifiers, signing, secure build secrets and release channels.
- Build release artifacts in CI and attach checksums/SBOM.
- Execute device matrix, API compatibility, penetration/security and acceptance testing.
- Prepare operator/admin manuals, support runbooks, architecture diagrams and known-limitations register.
- Release only after authorized sign-off; retain rollback artifacts and versioned database compatibility notes.
**Exit:** signed release candidate accepted by product owner and operational owner.

## Current code boundary
- Flutter interface set is represented in PR #48.
- Recorder capture metadata, upload validator, image lifecycle, fail-closed acceptance policy and processing ports are code-level contracts.
- New quarantine/storage ports are intentionally not registered in dependency injection and do not perform I/O.
- No OCR engine, chart digitizer, CLIMATOL runtime, AI training service or object-storage provider is claimed to exist.
- New scientific ERD and API contract remain proposals pending review.
- No hosted database was changed by this work.

## Release blockers that cannot be bypassed
- ERD/data dictionary approval.
- Approved storage/scanning/retention architecture and provisioned private storage.
- Authenticated staging identity and station/authority membership model.
- Real representative and independently labelled scientific datasets.
- Provider selection and provisioned compute for OCR, CLIMATOL and AI.
- Native Flutter build/signing and device-level acceptance.

## Recorder digitization enqueue gate (code contract)
- A queue submission is permitted only for an authenticated actor whose server-derived authority includes `recorder.digitize`, and only for a capture/asset pair with non-empty identifiers and an asset already in the `Accepted` state.
- Algorithm profile identifiers are bounded, canonical lowercase slugs; idempotency keys are bounded opaque tokens restricted to a safe ASCII character set.
- The pure policy rejects missing requests, unknown asset states, unaccepted assets, missing resource IDs, unsafe profile names and malformed idempotency keys.
- This policy does not itself resolve actor permissions, verify capture-to-asset ownership, persist idempotency records, enforce uniqueness/concurrency, or enqueue work. Those responsibilities remain mandatory in the application service and durable provider implementation; the port must not be wired to a fake in-memory queue.

