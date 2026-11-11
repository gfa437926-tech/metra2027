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
