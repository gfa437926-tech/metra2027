# METRA 2027 — Flutter, ASP.NET Core and New Database Completion Roadmap

Last updated: 2026-11-11T14:29:51Z
Repository: gfa437926-tech/metra2027
Default branch: main

## Target delivery

Complete the Flutter mobile application first, backed by one authoritative ASP.NET Core 10 API and the approved new Supabase/PostgreSQL project. Angular work follows only after Flutter has passed the agreed completion gates.

## Confirmed repository baseline

- Flutter client: `mobile/metra_mobile/`
- ASP.NET Core API: `backend/Metra.Api/`
- API tests: `backend/Metra.Api.Tests/`
- Database migrations: `supabase/migrations/`
- Workflow and role references: `docs/architecture/WORKFLOW-INVENTORY.md`, `docs/security/role-permission-matrix.md`, `docs/architecture/README.md`
- Deployment: `backend/DEPLOYMENT.md`, `docs/deployment/MULTI-ENVIRONMENT-HOSTING.md`
- New database target: `https://tbdnklyxjvbrilvnwgmq.supabase.co`
- Legacy database is read-only/out of scope. Never update, delete, truncate, or apply migrations to it.

The current Flutter client includes secure Supabase session handling, API configuration checks, a home shell, station directory/map, observation review, and a small test suite. Reports and several operational modules are placeholders or not yet present. The API already has JWT authentication, station-scoped authorization, station directory, registration, assignment, audit and observation workflow endpoints. This is a partial backend foundation, not a complete backend for every METRA workflow.

## Delivery sequence and gates

### Phase 0 — Correct repository and requirements baseline
Status: In progress.
1. Work only in this repository and its `mobile/metra_mobile/` Flutter folder.
2. Inventory the original requirements file, all project specifications, reference screenshots and legacy workflow files.
3. Produce a traceability matrix: requirement → Flutter screen → API endpoint → domain rule → database table/RPC → test.
4. Reconcile stale architecture/audit documentation against the current code before using it as a completion statement.
Gate: every required screen and workflow has an owner, fields, permissions, source data and acceptance tests.

### Phase 1 — Flutter UI inventory and design system
1. Complete the page/route inventory and Arabic label glossary.
2. Establish one responsive RTL shell, navigation and reusable components.
3. Match supplied reference screenshots; verify mobile sizes, tablets and accessibility.
4. Add loading, empty, offline, validation, permission-denied and server-error states to every screen.
Gate: visual review and navigation tests pass; no duplicate sidebars or orphan pages.

### Phase 2 — Identity and account lifecycle
1. Login, logout, secure session restore/refresh and account recovery.
2. Registration request and terms acceptance.
3. Pending/approved/rejected account states and two-stage review.
4. Station assignment request, approval, expiry and revocation.
5. Role and individual grant presentation based on server-authoritative access context.
Gate: tests prove no client-selected role/station can grant access; unauthorized and inactive accounts are blocked.

### Phase 3 — Station catalogue and station workspace
1. Consume only the approved new station catalogue.
2. Search/filter classic, automatic and synoptic stations.
3. Station detail, validated coordinates, elevation, metadata and catalogue approval status.
4. Coordinate history, map clustering and station audit.
5. Display unknown/missing values as unavailable; never fabricate station metadata.
Gate: counts and records reconcile with the approved station source; invalid coordinates are not plotted.

### Phase 4 — Meteorological observation workflows
Implement one workflow at a time, with complete field mapping and scientific validation:
1. Hourly observation entry and review.
2. Daily observation entry and review.
3. Weather phenomena.
4. Rainfall/precipitation.
5. Climate-hourly and climate reports.
6. Agricultural observations.
7. Soil-temperature records.
For each workflow: extract labels, field IDs, units, precision, valid ranges, missing markers, local/UTC time rules, cross-field validation, station attribution, idempotency, draft/submit/correction/approval/archive behavior, and exports.
Gate: API contract, server validation, database transaction and Flutter tests all pass before a workflow is marked complete.

### Phase 5 — Forecast-centre workspace
1. Station comparison by coordinates and verified elevation.
2. Live station observations only from an approved telemetry ingestion/provider.
3. Rainfall, wind speed/direction, temperature, humidity and pressure with source, timestamp, quality and stale-data indicators.
4. Bulletin list, detail, revisions and provenance.
5. Geographic comparisons, charts and maps.
6. Explicit unavailable state until a real feed and credentials are approved.
Gate: every displayed live value has a station/source/time/quality provenance; model forecasts are not mislabeled as station measurements.

### Phase 6 — Reports, analytics and exports
1. Station/date/period filters.
2. Daily, hourly, monthly, annual, climate and rainfall summaries.
3. Aggregation definitions and quality-control rules.
4. Excel/PDF/print/export with role-scoped data.
5. Pagination and performance for large station/time ranges.
Gate: report totals reconcile against source records and independently tested aggregation fixtures.

### Phase 7 — ASP.NET Core 10 backend completion
Keep API as the sole privileged database boundary. Complete/review:
1. Identity/JWT validation, account state, MFA/identity-provider integration and token/session revocation assumptions.
2. Domain/Application/Infrastructure/API separation where needed; consistent DTOs, ProblemDetails, versioning and OpenAPI.
3. Station catalogue, coordinate history and station review.
4. Registration, authority membership, station assignments, role/grant administration and audit.
5. Hourly/daily/phenomena/rainfall/climate/agriculture/soil observation APIs.
6. Draft, submit, idempotency, review, correction, approval, archive and immutable audit transitions.
7. Forecast-centre read APIs, telemetry ingestion adapters, data-quality and bulletin APIs.
8. Reporting/aggregation/export APIs.
9. Rate limits, request-size limits, bounded timeouts, cancellation, structured redacted logs, correlation IDs, health/readiness and monitoring.
10. Integration tests for every endpoint and exact permission boundary.
Gate: all business rules enforced server-side; no direct client writes to operational tables; no service-role key in clients.

### Phase 8 — New database schema and controlled data import
Target only the new project `tbdnklyxjvbrilvnwgmq`.
1. Inspect the current schema, constraints, indexes, RLS, RPC grants and migration history without changing it.
2. Create a schema-to-requirements matrix and identify missing entities/columns/relationships.
3. Design versioned, forward-only migrations; review SQL and rollback/restore plan.
4. Obtain explicit schema/migration approval before applying any new migration or changing RLS/policies.
5. Inventory the exact source data. The approved newly supplied station catalogue is the source of truth for current stations; do not silently reuse legacy station lists.
6. For any separately approved legacy historical data import: read-only extract from the old source, explicit field mapping, normalization, deduplication, foreign-key plan, dry-run report and row counts/checksums.
7. Import only approved rows using insert-only/upsert rules explicitly approved per entity. Never delete or rewrite the old source. Do not overwrite new authoritative station catalogue values with legacy values.
8. Verify row counts, nulls, duplicates, foreign keys, coordinate ranges, time zones, units and representative samples; retain an import manifest and audit trail.
Gate: written approval, successful dry-run, verified backup/restore point, reconciliation report and no writes to legacy DB.

### Phase 9 — Integration, security and release
1. Connect Flutter only to the deployed HTTPS ASP.NET API; no direct operational Supabase access.
2. Configure server-only Supabase service-role secret in host secret storage.
3. Configure Flutter with API HTTPS origin and only public Supabase publishable key where needed for Auth.
4. Run Flutter analyze/tests, .NET tests, database contract tests, integration tests and end-to-end journeys.
5. Test Android devices, offline/weak network, retry/idempotency, session expiry, accessibility and RTL.
6. Verify backups/restore, monitoring, alerting, incident response and rollback.
7. Build signed Android APK/AAB and iOS release on macOS/Xcode; verify release artifacts.
Gate: all CI checks green, authenticated end-to-end tests pass, no critical/high security findings, production readiness and data reconciliation signed off.

### Phase 10 — Flutter completion sign-off
Flutter is complete only when every requirement in the traceability matrix is implemented, connected to the API, tested, visually reviewed and documented. A placeholder, mock, disabled control or unverified screen is not complete. Only after this gate should Angular parity work begin.

## Data and security invariants

- Never modify or delete the legacy database or legacy repository.
- Never apply schema changes to the new database before explicit review and approval.
- Never put service-role credentials in Flutter, Angular, GitHub source, build arguments or client logs.
- No client-side role/station claim is trusted for authorization.
- No invented weather measurements, station elevations, coordinates, alerts or telemetry.
- Keep all imports auditable and source-attributed; preserve the source dataset and reconcile every imported row.
- Record every work round in GitHub with task ID, UTC timestamp, status, commit, tests and blockers.

## Immediate next task

FLT-001: finish the complete Flutter requirements/screen traceability inventory from the project specification and reference source files. Do not begin broad UI expansion or database writes until the inventory and data contract are established.
