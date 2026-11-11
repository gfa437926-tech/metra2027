# Assistant 02 — Backend & API Progress Report

- Repository: gfa437926-tech/metra2027
- Branch: work/backend-api-audit-assistant-2
- Updated at (UTC): 2026-11-10T23:39:06Z
- Round: 5 — station-isolation endpoint test follow-up
- Overall task status: In progress
- Draft PR: https://github.com/gfa437926-tech/metra2027/pull/22

## Work completed in this round
1. Rechecked the assistant-02 branch and compared it with main. At inspection time the branch comparison was diverged: 33 commits ahead and 2 behind.
2. Inspected the actual review queue endpoint and authorization service.
3. Confirmed the authorization check and service-role PostgREST queue read are separate operations; the queue read does not receive the actor ID.
4. Documented the TOCTOU scenario, security invariants, atomic RPC/read-model proposal, concurrency/revocation semantics, rejected alternatives and required test plan.
5. Added `docs/backend/B-013-REVIEW-QUEUE-TOCTOU-DESIGN.md`.
6. Updated the task tracker, change log and this progress report.
7. Read the master requirements for hourly/daily list, detail, correction and history workflows; drafted `docs/backend/OBSERVATION-READ-API-CONTRACT-DRAFT.md` for owner review.

## Files inspected
- `backend/Metra.Api/Features/Observations/ObservationQueueEndpoints.cs`
- `backend/Metra.Api/Security/StationAuthorizationService.cs`
- `backend/Metra.Api/Features/Observations/ObservationSubmissionEndpoints.cs`
- `backend/Metra.Api/Program.cs`
- `docs/backend/API-BACKEND-AUDIT-2026-11-11.md`
- `واجهات/مهما.md`
- `واجهات/تغيير.md`
- `docs/progress/assistant-02.md`
- Branch comparison against main.

## Files changed in this round
- `docs/backend/B-013-REVIEW-QUEUE-TOCTOU-DESIGN.md` (new)
- `docs/backend/OBSERVATION-READ-API-CONTRACT-DRAFT.md` (new)
- `واجهات/مهما.md`
- `واجهات/تغيير.md`
- `docs/progress/assistant-02.md`
- `docs/backend/API-BACKEND-AUDIT-2026-11-11.md`

## B-008 contract draft and disposition
A draft now describes general list, detail, version-history and correction routes, proposed filters/pagination, immutable version behavior, stale-version conflicts, station authorization and outstanding owner decisions. It is not an approved OpenAPI contract and no endpoints were implemented. B-008 remains in progress.

## Round 4 — QA review response and endpoint tests
A QA-06 PR review comment reiterated the P1 TOCTOU finding and specifically requested endpoint-level 401/403/400/503 tests plus an assertion that the queue service is not called on denied station scope. Added `backend/Metra.Api.Tests/Features/Observations/ObservationQueueEndpointTests.cs` with five WebApplicationFactory tests covering unauthenticated requests, invalid limit, denied permissions/no queue call, unconfigured dependency, and queue read failure. Tests were not run locally; no CI result for the new commit is confirmed yet. These tests do not remediate TOCTOU; B-013 remains open.

## Round 5 — station isolation endpoint test
Reviewed the QA-06 finding and the actual queue endpoint, authorization interface, Program.cs and test project. Extended `ObservationQueueEndpointTests.cs` with a sixth test: an actor granted station A is denied (403) when requesting station B; the test asserts that each authorization check used station B and the queue service was never called. The fake authorization service now supports a station-specific grant and records requested station IDs.

Commit: `efa5870e555d4f74584e44bd439002daf784afa3`. GitHub Actions run 42925098754 completed successfully on the test commit. Build, authorization contract checks, API build, Domain/API tests and production container image build all passed. No local test run is claimed. Tests were not run locally. This is endpoint-level fake-service coverage only, not a DB integration test and not a TOCTOU remediation. Revocation-before-request, concurrent read/revocation, atomic decision, DB-backed station isolation and E2E remain outstanding.

## B-013 finding and disposition
The current flow performs permission RPC checks first, then a separate PostgREST SELECT using the server service-role credential. A revocation can commit between the operations, leaving an in-flight request with a stale authorization decision.

Recommended remediation is one narrowly scoped database-side operation that validates the JWT-derived actor ID, exact station scope and current queue-read permission while selecting submitted rows atomically. The database reviewer must define snapshot/locking/serialization semantics. The decision operation must independently validate the decision-specific permission in the same atomic operation as the status transition.

B-013 remains **in progress**. The design document is not an implementation and does not close the finding.

## Verification evidence
| Check | Result | Evidence |
|---|---|---|
| Source-level review of queue and permission sequence | Completed | B-013 design document |
| GitHub Actions run 42925098754 | Success | https://github.com/gfa437926-tech/metra2027/actions/runs/42925098754 |
| GitHub Actions run 42924316537 | Success on commit d1ebc84289b3faca1a70c86413a531a5d33ecf78 | https://github.com/gfa437926-tech/metra2027/actions/runs/42924316537 |
| Previous Actions run 42922191087 | Success in round 2 | https://github.com/gfa437926-tech/metra2027/actions/runs/42922191087 |
| Previous Actions run 42922249720 | Success in round 2 | https://github.com/gfa437926-tech/metra2027/actions/runs/42922249720 |
| Production smoke test | Not run | Out of scope |

## Task status and calculation
13 assistant-02 tasks are tracked (B-001 through B-013):
- Completed: 7
- In progress: 4
- Blocked: 2
- Failed: 0

Completion = 7 / 13 × 100 = 53.8%, reported as 54%.
This percentage applies only to assistant 02 tasks, not the METRA project or total backend. It is unchanged in this round because the TOCTOU implementation and its tests remain outstanding.

## Remaining tasks
- B-008: report list/detail/correction/version-history API.
- B-009: blocked pending owner-approved required-field catalogue and reporting periods.
- B-010: cross-station isolation, token revocation, concurrency and end-to-end workflow tests.
- B-011: climate, rainfall, agriculture, soil-temperature, exports and archive-ledger API contracts.
- B-012: blocked pending confirmed production API host and approved client runtime configuration.
- B-013: implement approved atomic review-queue authorization/read and decision checks, then prove revocation/concurrency behavior.

## Next step
Obtain the owner-approved schema review for station grants/assignments and observations, plus an explicit revocation/concurrency guarantee. Only then implement the approved atomic operation and tests in an isolated approved test environment. Continue B-008 contract design in parallel.

## Explicitly not done
- No SQL, migrations, RPC deployment, RLS or seeds.
- No Supabase or database changes.
- No legacy project/database changes.
- No Angular or Flutter changes.
- No PR merge.
- No production deployment.
- No local .NET test execution.
- No new CI run claimed for round 3.

## Process correction recorded
The initial attempt to create this report in round 2 omitted the target branch and briefly created the file on the default branch. This was immediately corrected by deleting it from main; corrective commit:
https://github.com/gfa437926-tech/metra2027/commit/43c72da0604e49a74d2128cc9d3d881e2c912f26
A subsequent check confirmed the report is absent from the current main tree and exists on the assistant-02 branch. No source code or database files were changed by this incident; the add/delete commits remain visible in main history.


## Round 5 CI result
Actions run `42925098754` completed successfully on commit `efa5870e555d4f74584e44bd439002daf784afa3`: dependency restore/advisory checks, authorization contract checks, API build, Domain/API tests, and production container image build all passed. No local `dotnet test` run is claimed. The passing suite does not establish DB-backed revocation/race guarantees and does not close B-013.


## Round 6 — Reporting and observation archive API contract baseline (2026-11-11)

- Owner instruction received: proceed with reporting/archive Backend contracts, then bind the existing Flutter screens without redesign.
- Re-inspected the current ASP.NET Core 10 route composition, observation submission and queue source, Flutter API client and reports hub.
- Confirmed the existing GET `/api/v1/stations/{stationId}/observations` is a submitted review queue only; it is not a general historical archive.
- Confirmed the source-derived persisted observation fields available in the current queue projection: id, station_id, created_by, observation_type, observed_at, payload, status, submitted_at and created_at.
- Added `docs/backend/REPORTING-AND-OBSERVATION-ARCHIVE-API-CONTRACT-V1.md` (commit `d2c86150f8b81c20b190246d4e5e97d77b517af4`). It establishes the proposed archive list/detail route family, UTC filtering, bounded pagination, response envelope, authorization invariants, error mapping, and explicit deferment of history/corrections and scientific aggregation where schema or owner-approved rules are absent.
- The API interface baseline does not infer version/history storage, permissions, status enums, observation field catalogues, daily period boundaries, monthly/annual statistics, or export persistence.
- No API endpoint implementation or Flutter API binding is claimed in this round. The known B-013 authorization/read TOCTOU remains open; no new archive read endpoint will bypass it.
- No SQL, migration, RPC deployment, RLS, seed, database/Supabase write, production access, or METRA OLD change.
- Verification: documentation-only commit; no CI run claimed for this commit.

### Remaining implementation gates
1. Read-only schema review for observation, grant/assignment, audit/version and runtime-role objects.
2. Approve explicit archive-read permission and atomic read/revocation semantics.
3. Implement and DB-integration-test archive list/detail against the approved store/RPC.
4. Decide version/event storage before implementing history/correction.
5. Approve meteorological field units, daily period, completeness and monthly/annual aggregation rules before report calculations.
6. Bind the existing Flutter reports/archive UI to the verified API DTOs and test 401/403/404/409/503 plus station-scope behavior.

The earlier 54% assistant-02 task calculation is not recalculated from this documentation-only increment; implementation tasks remain open.


## Round 7 — Live read-only schema review for reporting/archive (2026-11-11)

- Confirmed the target project in the connected Supabase project list: `metra2027-angular`, ref `tbdnklyxjvbrilvnwgmq`, PostgreSQL 17.11, ACTIVE_HEALTHY. The legacy INSERT project was not queried.
- Ran read-only table metadata, migration inventory, RLS policy/grant inspection, function catalogue inspection, role-permission lookup and aggregate-only archive quality counts. No database mutation was issued.
- Confirmed `public.metra_observation_records`: 58,059 imported archive rows; 7 source types; 1,251 rows have NULL station_id and 13 have NULL observed_at. No fuzzy station linking is allowed.
- Confirmed `public.metra_observations` and `public.metra_observation_audit_events` each have 0 rows. The operational audit relation stores workflow event metadata, not prior payload snapshots.
- Confirmed `metra_api_runtime` has SELECT on account-state, assignment, permission-grant and station-catalogue relations, but no SELECT grant/policy on the imported archive or operational observation/audit relations. The operational observation migration explicitly revokes runtime privileges and grants service_role.
- Confirmed the current role-permission mapping has no `observation.archive.read` permission. Archive-read access cannot be inferred from `observation.review` or `observation.approve`.
- Added `docs/backend/REPORTING-ARCHIVE-READONLY-SCHEMA-REVIEW-2026-11-11.md` (commit `1d4cbe0955eda6810e6bc301ca24bf171f143335`).
- Updated `docs/backend/REPORTING-AND-OBSERVATION-ARCHIVE-API-CONTRACT-V1.md` with live schema facts (commit `be5915fbc506ce1935da8f8e0c14f46de380d255`).
- Safe architecture recommendation: read-only `metra_api_runtime` access with exact SELECT grants/RLS and a single parameterized SQL statement that checks active account, explicit archive-read permission and exact station assignment while reading the same station's archive rows. No service-role key in clients.
- Security/performance advisors were read. Relevant archive/observation tables have client-deny policies; runtime read policies/grants are missing. Advisor notices about support/equipment functions and unindexed FKs are recorded as separate follow-up findings; no index was dropped.
- No SQL write, DDL, migration, RPC, RLS, grant, seed, record update, legacy project query, or METRA OLD change.
- No API implementation, migration application or Flutter binding is claimed. Backend PR #22 and Flutter PR #34 remain Draft. The interface and schema review are now documented; implementation awaits explicit archive permission and least-privilege runtime access approval.


## Round 8 — Archive API and Flutter read-only integration (2026-11-11)

- Added Backend archive page/detail endpoints in `backend/Metra.Api/Features/Observations/ObservationArchiveEndpoints.cs`.
- Added a bounded Supabase RPC adapter using the server-only service-role credential; actor ID is derived from the validated JWT `sub` claim.
- Registered archive service and endpoints in `Program.cs`.
- Added proposed migration `20261111190000_add_station_scoped_observation_archive_read_rpcs.sql` with a private authorization predicate and two service-role-only SECURITY DEFINER RPCs. It checks active account, explicit approved and time-valid `observation.archive.read` grant for the station's authority, active approved station assignment and approved active station before returning only exact-station imported rows. The predicate is checked inside the RPC call; clients have no direct SELECT or RPC execute rights.
- Migration intentionally does not add a role mapping or grant the permission to any user. No one receives archive access until an authorized authority grants the new permission through the existing permission-grant workflow.
- Added `supabase/tests/observation_archive_read_security.sql` for function existence, client-role denial and no automatic role mapping.
- Added Backend request-guard tests for imported type allow-list, UTC-only time ranges and bounded pagination.
- Backend CI run `43085399691` completed successfully on the archive API/test commit; run `43085435929` also passed after contract documentation updates.
- Flutter branch now has typed archive list/detail DTOs, authenticated API methods, UTC date range and type filters, a paginated archive list with server `hasMore`, raw source-payload detail, 403/404/503/empty states, and an entry action in the existing reports hub. No reports-hub redesign.
- Added API and widget tests for archive list/detail, filters and selection prerequisites.
- Flutter CI initially exposed compile/analyzer issues and a Flutter 3.50 Material import deprecation. The compile issue was fixed; imports were narrowly annotated pending the upstream Flutter Material package migration. Latest Client CI run `43086553383` is pending; no pass is claimed yet.
- No database migration applied. No user permission issued. No SQL write, RLS/grant change, seed, data update, production deploy, legacy INSERT access or METRA OLD change.

### Current gates
1. Confirm latest Flutter CI is green and fix any remaining analyzer/test failures.
2. Obtain approval for the archive permission audience (no role auto-assignment has been made).
3. Obtain approval for the cost of a Supabase development branch before creating an isolated database environment; the main METRA 2027 database remains unchanged.
4. Apply the migration only to that isolated branch and run SQL security + station-isolation integration tests.
5. Only after successful isolated tests, request approval for production migration.
6. Daily/hourly/monthly/annual scientific report calculations, payload-version history, Climatol and export jobs remain separate contracts and are not claimed complete by the imported archive reader.


## Round 9 — Flutter CI correction, archive permission scope and isolated DB test harness (2026-11-11)

### Flutter CI
- Re-inspected the failing archive detail widget test and the actual screen implementation.
- Identified the test defect: the detail screen renders its payload title below the initial viewport in a lazily built ListView; the previous test searched for that off-screen child before scrolling, so waiting/pumping could never make it appear.
- Updated mobile/metra_mobile/test/observation_archive_screen_test.dart to scroll the detail ListView before asserting the payload title and JSON content.
- Latest Flutter commit: 3b99890a5882ac8e49248ad25d6ffbfac7fa7503.
- Client CI run #1130 (43098264612) is queued; no passing result is claimed. Flutter SDK is not installed in the current execution container, so local Flutter tests were not run.
- PR #34 branch currently compares cleanly with main (71 commits ahead, 0 behind); it remains Draft pending green CI and review.

### Archive permission scope
- Added docs/security/OBSERVATION-ARCHIVE-READ-PERMISSION-SCOPE.md.
- The phase policy documents eligibility for station_head, station_auditor and chief_auditor only.
- Eligibility is explicitly not a grant. No role mapping, user grant, registration-time assignment or implicit inheritance is created.
- Each future grant must be individual, approved, authority/station-scoped, time-bounded, revocable and audited. The grant-issuance workflow must enforce the eligible role set and two-person approval before any real grant is issued.
- The assignment role column and grant-issuance RPC contract are not yet certified; therefore zero live grants are authorized. This remains a security acceptance gate.

### Isolated database test environment
- The local container has no Docker, Supabase CLI or PostgreSQL server; no local DB test is claimed.
- Added a disposable PostgreSQL 17 service job to the existing .github/workflows/backend-ci.yml workflow. It uses GitHub Actions ephemeral service containers and does not provision a hosted Supabase project or consume a paid Supabase branch.
- Added supabase/tests/fixtures/archive_schema_bootstrap.sql to model only the verified schema surface required by the archive RPC migration and the Supabase JWT role claim helper.
- Added supabase/tests/observation_archive_read_integration.sql for explicit grant, missing grant, inactive account, expired grant, revoked grant, expired station assignment, cross-station denial, unlinked/demo exclusion, pagination and UTC range behavior.
- Existing static SQL security test checks RPC existence, service-role execute access, client-role denial and absence of role auto-grants.
- Updated the proposed RPC guard from deprecated auth.role() to auth.jwt() ->> 'role', matching current Supabase Auth guidance.
- Backend CI run #1542 (43098429680) is queued; no migration or integration test pass is claimed yet.
- The disposable PostgreSQL fixture is a focused migration/authorization test harness, not a complete Supabase stack. A full local Supabase CLI run still requires Docker and a complete, reviewed migration baseline.

### Scientific report contracts
- Added docs/backend/SCIENTIFIC-REPORTING-CLIMATOL-EXPORT-CONTRACT-DRAFT-V1.md covering hourly, daily, monthly, annual, specialist domains, Climatol and exports.
- The existing archive reader returns raw source-preserving payloads for the seven verified imported types; it does not calculate scientific aggregates.
- Scientific implementation remains blocked on extracting the authoritative requirements archive and owner approval of field units, timestamp conventions, daily period, missing/trace semantics, quality rules, aggregation operators and Climatol review authority. No formulas, units or fake values have been invented.
- No scientific calculations, Climatol jobs or export jobs are represented as implemented by this round.

### Safety and remaining blockers
- No live database writes, DDL, migration application, RLS/grant changes, seed or production deployment.
- No access to project INSERT and no METRA OLD access or changes.
- No service or resource with a non-zero cost was created.
- Backend PR #22 remains Draft and is still 72 commits ahead / 30 behind main at last comparison; safe rebase/reconciliation is still required before merge.
- Flutter PR #34 remains Draft; latest Client CI run #1130 is queued.
- Backend PR #22 latest CI run #1542 is queued.
- No percentage increase is claimed until the queued CI jobs complete and the isolated database tests pass.
