# METRA 2027 — Backend / .NET / API Audit
- Date: 2026-11-11
- Role: Assistant 2 — Backend and API
- Repository: gfa437926-tech/metra2027
- Audited baseline: main at 87f71356083843b2abdef76baf011a82510686be
- Working branch: work/backend-api-audit-assistant-2
- Status: first-pass audit; not a production-readiness sign-off

## Scope and source evidence
Reviewed the repository README, ASP.NET Core project and Program.cs, endpoint/service source files under backend/Metra.Api, the test project and its 20 C# test files, deployment guidance, architecture guidance, and the master page/workflow/test specification on branch docs/metra-complete-page-test-matrix.

The requested tracking files واجهات/مهما.md and واجهات/تغيير.md, and the master specification, were not present on main at the audited baseline. The master specification was located and read on docs/metra-complete-page-test-matrix. Tracking files are being introduced on this independent branch. No old repository or old database was accessed.

## Actual backend shape
- ASP.NET Core 10 / net10.0.
- Minimal APIs; no MVC Controllers directory was found in the backend tree.
- Endpoint contracts and service interfaces/implementations are currently colocated in feature files; no separate DTO/Contracts or Application/Infrastructure project was found in the audited backend tree.
- API composition and authentication are in backend/Metra.Api/Program.cs.
- Tests are in backend/Metra.Api.Tests; 20 C# test files were found.
- Supabase is accessed server-side through IHttpClientFactory and PostgREST/RPC calls. No schema changes, SQL execution, migration execution, RLS changes, or seed execution were performed.

## Endpoint inventory observed in source
### Health and validation
- GET /api/v1/health — anonymous liveness.
- GET /api/v1/ready — anonymous readiness with server-side catalogue probe.
- POST /api/v1/observations/daily/validate
- POST /api/v1/observations/hourly/validate
- POST /api/v1/observations/phenomena/validate

### Stations and observations
- GET /api/v1/stations
- POST /api/v1/stations/{stationId}/review
- POST /api/v1/stations/{stationId}/observations
- GET /api/v1/stations/{stationId}/observations — submitted review queue.
- POST /api/v1/stations/{stationId}/observations/{observationId}/decision
- GET /api/v1/stations/{stationId}/users
- GET /api/v1/stations/{stationId}/audit-log
- GET /api/v1/stations/{stationId}/assignable-roles
- POST /api/v1/stations/{stationId}/assignments
- POST /api/v1/stations/{stationId}/assignments/{assignmentId}/decision
- POST /api/v1/stations/{stationId}/assignments/{assignmentId}/revoke

### Registration and authority access
- GET /api/v1/registration-roles
- GET /api/v1/account/registration-status
- POST /api/v1/registration-requests
- GET /api/v1/stations/{stationId}/registration-requests
- POST /api/v1/stations/{stationId}/registration-requests/{requestId}/decision
- GET /api/v1/stations/{stationId}/system-registration-requests
- POST /api/v1/stations/{stationId}/system-registration-requests/{requestId}/decision
- GET /api/v1/stations/{stationId}/registration-audit
- GET /api/v1/stations/{stationId}/system-registration-audit
- GET /api/v1/authorities
- GET /api/v1/authorities/{authorityId}/membership-roles
- GET /api/v1/authorities/{authorityId}/permission-options
- GET /api/v1/authorities/{authorityId}/access-queue
- GET /api/v1/authorities/{authorityId}/access-audit
- POST /api/v1/authorities/{authorityId}/memberships
- POST /api/v1/authorities/{authorityId}/memberships/{membershipId}/decision
- POST /api/v1/authorities/{authorityId}/memberships/{membershipId}/revocation
- POST /api/v1/authorities/{authorityId}/permission-grants
- POST /api/v1/authorities/{authorityId}/permission-grants/{grantId}/decision
- POST /api/v1/authorities/{authorityId}/permission-grants/{grantId}/revocation

Route inventory is source-derived. It does not establish that the corresponding database RPCs, schema objects, production host, or client integrations are operational.

## Positive security and reliability controls observed
1. JWT Bearer validates issuer, audience, lifetime and signing key; HTTPS metadata is required; inbound claims are not remapped and the subject claim is used as identity.
2. A fallback authorization policy requires an authenticated user unless a route explicitly opts into anonymous access.
3. Server-side Supabase integration requires an HTTPS project URL and a server-only service-role key; the deployment guide explicitly forbids exposing it to Angular/Flutter.
4. Supabase HttpClient instances are configured with an 8-second timeout.
5. Station permission lookup fails closed for missing configuration, empty identifiers, non-success responses, malformed JSON and timeouts.
6. Station-scoped endpoints derive actor identity from the verified JWT subject and check exact station permissions.
7. Observation submission validates idempotency-key shape, observation type, object payload and a 64 KiB payload limit.
8. Queue and directory reads have bounded pagination/limits in the reviewed source.
9. Readiness is separate from liveness and includes a server-authenticated catalogue round trip.
10. The tests include authentication, readiness, authorization failure behavior, domain validators and request guards.

## Findings and priorities
### P1 — UTC-only timestamp contract was not enforced at submission boundary
The master specification explicitly requires UTC-only report timestamps. ObservationSubmissionRequestGuard previously checked only that ObservedAt was present; DateTimeOffset values with non-zero offsets were accepted. This branch now rejects non-zero offsets with observation_time_must_be_utc and adds a regression test. This is a narrow contract fix and does not alter database schema or stored data.

### P1 — Daily validation endpoint does not supply required-field rules
The daily endpoint calls DailyObservationValidator.Validate(values) without requiredFields. The validator supports an optional required-field set, but no authoritative set is supplied by the endpoint. Therefore this endpoint cannot currently enforce daily requiredness. The master specification says the exact daily required fields and period boundaries remain TBD/owner approval. Do not invent them; obtain an approved field catalogue and wire it into the contract with tests.

### P1 — Unknown observation field names can be silently ignored
The daily and hourly validators iterate known rule dictionaries but do not reject every unknown key. The request guard bounds field count/name/value lengths but does not validate keys against an approved catalogue. A misspelled or unsupported field may therefore be omitted from semantic validation. A strict allow-list should be introduced only after the owner-approved field catalogue is complete, so valid but not-yet-inventoried fields are not accidentally rejected.

### P1 — Review queue has a time-of-check/time-of-use authorization window
The queue endpoint checks station permission through a separate authorization RPC, then the queue service performs a service-role PostgREST read by station ID. A station assignment or grant revoked between those two operations may still permit the in-flight request to return queue data. The master specification explicitly requires atomic queue authorization/read or equivalent TOCTOU protection. Resolve with a reviewed server-side RPC/read model that rechecks actor and scope as part of the data read; do not invent or execute SQL in this task.

### P1 — Operational read/correction API coverage is incomplete relative to the master page specification
The reviewed API exposes a submitted review queue and decision routes, but no complete general report list/detail/version-history/correction routes were found in the backend tree for daily/hourly observation workflows. The master specification requires lists, details, corrections, retained versions and auditable transitions. These contracts need design and implementation before client parity can be claimed.

### P1 — API surface does not yet cover all specialist/reporting workspaces
No API routes for climate, rainfall, agricultural, soil-temperature, monthly/annual report aggregation, export/print, or the manual Excel archive-confirmation ledger were found in the reviewed backend route inventory. These are required/planned in the master specification; formulas, field definitions and access scope have unresolved owner decisions.

### P1 — Production readiness is not demonstrated
The deployment guide states that no production host is specified and that publishing the container does not deploy it. Production requires a real HTTPS host, secret-manager configuration, exact CORS origins, live readiness/authenticated integration checks and client runtime configuration. The current audit did not access a production host or secrets.

### P2 — API contract conventions need consolidation
Validation failures commonly return small { error } objects, while dependency failures use ProblemDetails and conflict paths use bespoke error identifiers. Request/response records are colocated with endpoint implementations. Define a consistent error envelope, stable response schemas, pagination conventions and OpenAPI examples before Angular/Flutter integration expands.

### P2 — Test coverage is stronger for guards/domain units than full workflow integration
Twenty backend C# test files exist. Source inspection shows tests for domain validation, request guards, authentication/readiness and selected service behavior. The master specification additionally calls for cross-station negative tests across every read/write/filter/export path, token revocation, concurrent decisions, correction/version history, and full submit-review-correct-approve E2E workflows. Their completion is not established by the presence of current unit tests.

### P2 — Decision endpoints should have consistent authorization structure
Observation decision currently performs explicit subject and permission checks in the handler rather than using the shared endpoint-filter helper. This is not evidence of an authorization bypass in the inspected code, but it creates a consistency and maintenance risk. Normalize authorization patterns only after reviewing every endpoint's authority/station scope and preserve the distinct permission required by each decision.

## Client integration requirements
- Both Angular and Flutter should call the same versioned API; no client should call PostgREST or use the service-role key.
- Send Supabase access token as Bearer token on protected endpoints.
- Use UTC timestamps with explicit Z/zero offset for all report timestamps and filters; never convert to local time.
- Treat 401 as authentication/session failure, 403 as permission/scope denial, 409 as conflict/idempotency/stale transition, 400 as validation failure, and 503 as dependency/service unavailable.
- Use server responses as the authority for account, assignment, station and permission state.
- Implement list/detail/queue pagination and stable error handling only after response contracts are documented.
- Keep drafts/previews distinct from persisted submissions.
- Do not claim live data or production connectivity until real host and authenticated end-to-end requests are verified.

## Changes made on this branch
- Added an explicit UTC offset check to ObservationSubmissionRequestGuard.
- Added a regression test rejecting a non-zero-offset timestamp.
- Added the audit and tracking documents.
- No database, SQL, migration, RLS, seed, Angular or Flutter files were changed.

## Verification status
- Source-level review completed.
- Local Backend tests were not executed in this environment.
- GitHub Actions run 42922191087 completed with success: https://github.com/gfa437926-tech/metra2027/actions/runs/42922191087
- GitHub Actions run 42922249720 completed with success: https://github.com/gfa437926-tech/metra2027/actions/runs/42922249720. Its job steps confirm package restore/advisory checks, authorization contract checks, API build, Domain/API tests and production container image build all succeeded.
- These are CI results, not evidence of a local test run or production deployment.
- No production endpoint was contacted.

## Next work
1. Confirm CI for this branch and fix any regression.
2. Obtain owner-approved daily/hourly field catalogue and UTC period rules.
3. Define versioned API contracts for report list/detail/correction/history.
4. Add cross-station, token revocation, stale decision and end-to-end tests.
5. Complete specialist module and archive-ledger API gap analysis.
6. Reconcile client runtime integration with the real deployed API host after owner supplies/configures it.
