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

### Digitization orchestration preflight hardening
- Empty capture or accepted-asset identifiers are rejected before calling authorization, asset-state or outbox providers.
- This preflight validates request shape only and does not reveal resource existence; authorized resource-state lookup remains ordered after station/capture/asset authorization.
- Unit tests assert zero dependency calls for either malformed identifier.

### Recorder audit attribution hardening
- Recorder audit events now carry the validated actor subject, asset, optional capture/job IDs, correlation ID, transition and safe reason code.
- Added fail-closed validation for required identifiers and bounded ASCII token metadata; control characters, free-form text and unbounded values are rejected.
- Added unit tests for missing IDs, unsafe correlation values, noncanonical transition values and free-form reason text.
- This remains a provider-neutral contract. No audit database table, provider registration or production write path is enabled by this change.


### Recorder image upload orchestration (code contract)

- `RecorderImageUploadIntakeService` now composes the existing upload primitives into a fail-closed application sequence: authenticate actor, authorize capture/asset/station scope, read current lifecycle state, bounded-read the stream, validate filename/content signature/media type/SHA-256, write only to private quarantine, validate the storage adapter's returned asset ID/length/hash/media type and digest equality, then conditionally record `AwaitingUpload → UploadedQuarantined`.
- The state-store port must commit the expected-state compare-and-set and immutable audit event atomically. A failed storage-result check or state race triggers a quarantine-object rollback request; expiry cleanup is a distinct operation.
- Tests cover denied access before state lookup, successful quarantine handoff, digest mismatch cleanup and compare-and-set conflict cleanup.
- This closes the application orchestration contract only. The service is not registered or exposed, and there is no production object store, scanner, persistence adapter, endpoint, retry worker or deployment secret configuration. Production activation remains blocked on approved schema, real provider integration, cleanup/retention guarantees and integration/security testing.

### Upload commit ambiguity and quarantine reconciliation
- The upload asset-store contract returns one of `Committed`, `StateConflict` or `OutcomeUnknown`.
- A confirmed state conflict permits quarantine rollback. `OutcomeUnknown` must preserve the object in private quarantine and return a reconciliation-required result; a provider timeout or lost response must never be misreported as a definite conflict.
- A reconciler must compare the durable asset row, audit transaction and object metadata before deciding whether to retain, resume or clean up the staged object. No speculative deletion is allowed.
- Unit tests verify that the unknown-commit path does not delete the quarantined object.

### Concurrent recorder upload isolation
- Every upload receives a server-generated attempt identifier; the quarantine provider writes to an immutable object key scoped by both asset ID and attempt ID.
- Returned metadata must echo the exact attempt ID. Cleanup deletes only that attempt object, never a shared asset-level quarantine key, preventing one concurrent request from overwriting or deleting another request's evidence.
- The durable asset row records the committed attempt/object reference. Concurrency and replay tests must prove stale attempts cannot replace the winning upload.

### Live Supabase migration-history reconciliation gate (2026-11-15)
- Read-only inspection of project `tbdnklyxjvbrilvnwgmq` confirmed that it is not empty: 46 application tables exist across 10 domain schemas and 86 migration records are applied.
- The current Git branch tracks only five SQL files under `supabase/migrations/`. This source-of-truth mismatch blocks reproducible database delivery and any additional hosted schema work.
- All 46 inspected application tables have RLS enabled. Twenty-one no-policy findings are informational; the checked `anon` and `authenticated` roles had no SELECT/INSERT table privileges on these tables. Complete UPDATE/DELETE/EXECUTE grants and exposed-schema settings still require review.
- Do not remove the 76 indexes flagged as unused: most domain tables are empty and representative workload evidence is not yet available.
- Required order: recover the exact 86 migration SQL sources; reconcile Git and live schema objects; verify grants, RLS, RPC and Data API exposure; replay against a disposable empty database; obtain approval of the scientific ERD; only then consider any new migration.
- No hosted SQL writes, migrations, seeds or legacy-database changes were made during this inspection.
- Evidence and table inventory: `docs/architecture/METRA-SUPABASE-READONLY-SCHEMA-BASELINE-2026-11-15.md`.

### Live migration SQL recovery status
- Recovered all 86 non-null SQL statements from `supabase_migrations.schema_migrations` into `supabase/live-schema-history/`, using each exact recorded version and name. Every record contained exactly one statement.
- The recovered files are intentionally stored outside `supabase/migrations/` and are **not executable migration inputs**. Do not run them wholesale: the archive includes historical context-dependent and destructive migrations.
- The original five Git migration files remain unchanged. Exact comparisons identified divergence in three files and timestamp/name mapping differences in two. The archive provides the authoritative raw statements for reconciliation.
- Remaining blocker: curate and validate a canonical replay sequence against a disposable empty PostgreSQL database, compare the resulting schema with the live project, and approve the ERD before any new hosted DDL.

- Follow-up reconciliation aligned all five tracked active migration files byte-for-byte with the corresponding recovered live statements and corrected the two mismatched version prefixes. The active folder still contains only five of the 86 applied migrations; the other 81 remain archived outside the CLI migration path.
- Added `scripts/verify_live_schema_history.py` and a Backend CI step to enforce the 86-file archive inventory, version range, unique IDs, non-empty SQL, and exact parity for every active-folder migration against the recovered source. This integrity check does not execute SQL or prove clean replay.

### Supabase runtime identity production gate
- Read-only role inspection confirms that `service_role` has `BYPASSRLS=true` and can SELECT all 46 inspected application tables. Several .NET Supabase services currently authenticate PostgREST calls with the server-only `Supabase:ServiceRoleKey`.
- The database's `metra_api_runtime` role is `NOLOGIN`, `NOBYPASSRLS`, has limited table grants, and currently has no EXECUTE grants on inspected application functions. It is not yet a working API identity.
- `anon` and `authenticated` have no table CRUD grants and no function EXECUTE grants in the inspected application domain schemas; all 46 tables have RLS enabled. Twenty-one no-policy advisor findings are informational under this deny-by-default grant state.
- Hosted Data API exposed-schema settings were not established by the read-only database session and must be checked separately.
- Before production, approve and implement a least-privilege API runtime identity (or a documented, tightly bounded RPC gateway exception), grant only approved RPC execution, and prove cross-authority/station and lifecycle denial tests using that exact identity. Do not grant the runtime role service_role membership or BYPASSRLS merely to make the API work.
- Security review: `docs/security/METRA-SUPABASE-RUNTIME-IDENTITY-REVIEW-2026-11-15.md`.

### Live .NET API / Supabase schema compatibility blocker
- Read-only catalogue checks show the current .NET API's expected `public.station_catalogue`, `public.station_coordinates`, `public.metra_observations`, station-permission RPC, observation-submit/review RPCs and station-audit RPC are absent.
- The live database instead contains `catalog.stations`, `catalog.station_locations` and `observations.submissions` in the normalized greenfield schema. The expected public METRA RPCs are not present in the current function catalogue.
- Current .NET adapters still call the old public table/RPC names. Their compile/unit CI does not prove live database compatibility; station directory, station authorization and observation workflows remain unready until the API is mapped to the new schema and matching approved server-side contracts exist.
- Do not restore the old `public.metra_*` schema as a shortcut. Review the greenfield ERD, design new versioned persistence/RPC contracts, bind actor identity to the validated JWT, then test in an isolated disposable database before any hosted migration.
- Detailed evidence: `docs/architecture/METRA-SUPABASE-API-SCHEMA-COMPATIBILITY-REVIEW-2026-11-15.md`.

### Deployed Supabase Edge Function schema mismatch
- Read-only source inspection found five active Edge Functions (`station-directory`, `registration`, `registration-approvals`, `observations`, `station-review`), all with `verify_jwt=true` and explicit `auth.getUser` checks.
- All five still query old public tables such as `station_catalogue`, `metra_account_states`, `metra_observations`, and old registration/permission tables; they also call old RPCs that are absent from the live schema.
- Each function uses `SUPABASE_SERVICE_ROLE_KEY` for its admin client and wildcard `Access-Control-Allow-Origin: *`. JWT verification is positive, but the service-role path bypasses RLS and wildcard CORS is too broad for final production configuration.
- Treat deployed status as deployment metadata only, not proof of working data access. Do not deploy or disable functions without a reviewed replacement plan. Rebuild their data contracts against the normalized `iam`, `catalog`, and `observations` model, select a least-privilege identity, restrict CORS, and test the full workflow in isolation.
- Review: `docs/architecture/METRA-SUPABASE-EDGE-FUNCTION-COMPATIBILITY-REVIEW-2026-11-15.md`.

### Greenfield .NET persistence mapping — 2026-11-15
- Added `docs/architecture/METRA-GREENFIELD-API-PERSISTENCE-MAPPING-AND-RPC-CONTRACTS-2026-11-15.md`, mapping station directory, IAM, registration, observation submission/review/archive, station users/assignments and audit operations to the inspected `iam`, `catalog`, `ref`, `observations`, `files` and `audit` schemas.
- The blueprint specifies versioned logical server operations, actor-from-JWT enforcement, idempotency, optimistic concurrency, atomic audit, exact station/organization scope and isolated PostgreSQL acceptance tests.
- It explicitly records the station projection differences (no legacy `is_demo`, `local_station_code`, or `station_coordinates` fields) and the need to use validity-bounded `catalog.station_locations`.
- This is documentation/design only. The old .NET adapters still reference absent legacy public objects; the new contracts are not deployed, no DDL/grants/data were changed, and no hosted migration is authorized.
- Next engineering work must implement typed greenfield .NET adapters against the disposable canonical schema and replace routine service-role calls with an approved least-privilege caller identity before enabling operational Flutter workflows.

- CI scope clarification: the current Path N isolated PostgreSQL build still applies the repository's legacy `public.metra_*` baseline, while transfer-pack end-to-end tests use synthetic fixtures. These checks do not certify replay of the normalized greenfield `iam/catalog/ref/observations` schema. A separate greenfield empty-database replay job is required after its canonical migration sequence is reviewed and approved.
