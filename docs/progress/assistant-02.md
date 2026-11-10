# Assistant 02 — Backend & API Progress Report

- Repository: gfa437926-tech/metra2027
- Branch: work/backend-api-audit-assistant-2
- Updated at (UTC): 2026-11-10T23:34:04Z
- Round: 3 — review-queue TOCTOU analysis and mitigation design
- Overall task status: In progress
- Draft PR: https://github.com/gfa437926-tech/metra2027/pull/22

## Work completed in this round
1. Rechecked the assistant-02 branch and compared it with main. At inspection time the branch comparison was diverged: 14 commits ahead and 2 behind.
2. Inspected the actual review queue endpoint and authorization service.
3. Confirmed the authorization check and service-role PostgREST queue read are separate operations; the queue read does not receive the actor ID.
4. Documented the TOCTOU scenario, security invariants, atomic RPC/read-model proposal, concurrency/revocation semantics, rejected alternatives and required test plan.
5. Added `docs/backend/B-013-REVIEW-QUEUE-TOCTOU-DESIGN.md`.
6. Updated the task tracker, change log and this progress report.\n7. Read the master requirements for hourly/daily list, detail, correction and history workflows; drafted `docs/backend/OBSERVATION-READ-API-CONTRACT-DRAFT.md` for owner review.

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
- `docs/backend/B-013-REVIEW-QUEUE-TOCTOU-DESIGN.md` (new)\n- `docs/backend/OBSERVATION-READ-API-CONTRACT-DRAFT.md` (new)
- `واجهات/مهما.md`
- `واجهات/تغيير.md`
- `docs/progress/assistant-02.md`
- `docs/backend/API-BACKEND-AUDIT-2026-11-11.md`

## B-008 contract draft and disposition\nA draft now describes general list, detail, version-history and correction routes, proposed filters/pagination, immutable version behavior, stale-version conflicts, station authorization and outstanding owner decisions. It is not an approved OpenAPI contract and no endpoints were implemented. B-008 remains in progress.\n\n## B-013 finding and disposition
The current flow performs permission RPC checks first, then a separate PostgREST SELECT using the server service-role credential. A revocation can commit between the operations, leaving an in-flight request with a stale authorization decision.

Recommended remediation is one narrowly scoped database-side operation that validates the JWT-derived actor ID, exact station scope and current queue-read permission while selecting submitted rows atomically. The database reviewer must define snapshot/locking/serialization semantics. The decision operation must independently validate the decision-specific permission in the same atomic operation as the status transition.

B-013 remains **in progress**. The design document is not an implementation and does not close the finding.

## Verification evidence
| Check | Result | Evidence |
|---|---|---|
| Source-level review of queue and permission sequence | Completed | B-013 design document |
| Local .NET tests in this round | Not run | No local execution claimed |
| New GitHub Actions run in this round | Not run / no result yet | No new CI result claimed |
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
