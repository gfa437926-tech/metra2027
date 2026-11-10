# METRA 2027 — QA Audit Report

**Audit date:** 2026-11-11  
**Base:** main  
**Branch:** qa/metra-2027-test-coverage-audit  
**Scope:** test inventory, CI wiring, coverage gaps and integration-risk triage. No application logic or database schema was changed.

## Executive result

The repository has a meaningful backend test foundation and basic Flutter tests, but it does not yet have a complete cross-client quality gate. The inspected `main` baseline has Angular build verification only; no R/Climatol test project or browser E2E/accessibility suite was found there at initial audit time. UTC-only behavior is described in API examples but is not evidenced by a dedicated cross-layer test suite.

**Execution status:** no local test command was executed by QA-06. The available GitHub integration can inspect repository contents and CI definitions but does not provide a shell runner for npm, flutter, dotnet, PostgreSQL or R in this session. No QA-06 test is marked passed or failed. Historical CI outcomes in README are historical and are not a run of the QA branch.

## Findings and priorities

### P0 — release-blocking verification gaps
1. **No real identity / authority / cross-station integration proof.** Security documentation itself says real-user, cross-authority, self-approval and concurrency tests remain outstanding. Existing unit tests do not establish live authorization enforcement across API + database.
2. **No authenticated end-to-end workflow.** No E2E runner/workflow was found in the inspected main baseline. Login, station-scoped observation submission, review, approval/rejection and forbidden cross-station access are not proven end to end.
3. **UTC-only invariant lacks dedicated tests.** API contract documentation uses ISO-8601 UTC (Z), but no identified test suite proves the invariant through Angular, Flutter, API and persistence.
4. **R/Climatol test scope is absent from the inspected main baseline.** Follow-up review found R implementation/test work on PR #23's stacked feature branch; see branch dependency note below. QA cannot certify that branch until its base and latest CI are validated.

### P1 — important coverage gaps
5. **Angular has no test target in the inspected baseline.** `angular-app/package.json` defines build/start/watch only; no unit/component test command or test dependencies were declared in the baseline. CI runs production build only.
6. **Flutter coverage is narrow.** Three test files existed in the inspected baseline and CI runs analyze + test, but explicit RTL, responsive viewport, semantics/accessibility, validation/error-state and cross-station authorization cases were not identified from the inventory.
7. **Backend endpoint integration depth is unclear.** The test project has domain/request-guard/security tests; add test-server integration tests for actual routes, middleware, JWT claims, ProblemDetails and status-code contracts.
8. **SQL tests are contract scripts, not full database integration tests.** Twelve shell checks run in backend CI, but a live PostgreSQL test layer is needed for RLS, concurrent decisions, rollback and audit immutability.
9. **Shared coordination-file collision risk.** PR #21 and PR #22 independently add `واجهات/مهما.md` and `واجهات/تغيير.md` against `main`, with different contents. Integrator must consolidate both histories before merging; do not overwrite one assistant's entries with the other.

### P2 — CI reliability / maintainability
10. **Backend workflow path filter omits the active migration directory.** It watches `database/migrations/**`, while current migrations are under `supabase/migrations/**`. A migration-only change may not trigger this workflow.
11. **Backend CI path filters omit API contract documentation.** Consider adding `docs/api/**` and relevant QA contract changes to workflow filters.
12. **Coverage reporting is not configured.** Add machine-readable coverage output and thresholds after missing test layers are established.
13. **Client CI workflow is being changed in PR #27.** Re-review path filters and test commands on that branch before treating them as baseline behavior.

## Existing inventory (main baseline snapshot)
- .NET: 20 C# test files in Domain, Features and Security.
- Flutter: 3 test files.
- SQL: 12 shell contract scripts under database/tests.
- Angular: no test script/test dependencies found; build only.
- R: no project or test files found in the inspected main baseline at initial audit time.
- E2E/accessibility: no runner or workflow found in the inspected main baseline.

See REQUIREMENTS-TEST-MATRIX.md for per-area traceability.

## Repository artifacts not found on main / QA branch
The following requested files were absent from both branches at follow-up:
- `واجهات/مهما.md`
- `واجهات/تغيير.md`
- `واجهات/README.md`
- `docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md`

PR #21 and PR #22 each add the first two paths independently; this is a merge coordination risk. QA did not create a third competing version.

## Follow-up audit — cross-assistant integration review (2026-11-10T23:30:26Z)

### Coordination-file collision risk — P1
- PR #21 (`assistant-3/flutter-mobile-audit`) adds `واجهات/مهما.md` and `واجهات/تغيير.md`.
- PR #22 (`work/backend-api-audit-assistant-2`) independently adds the same two paths against `main`, with materially different contents and task histories.
- Both PRs are open and target `main`. Integrator must consolidate the histories into one canonical file set before merging both; do not accept one file set by overwriting the other.
- The requested coordination files remain absent on `main` and on the QA branch. QA did not create another competing copy.

### Branch dependency and changed scope
- PR #23 (`work/climate-analytics-r-hardening`) targets `work/climate-analytics-r-bootstrap`, not `main`. It adds/updates `services/climate-analytics-r/tests/testthat/test-worker.R` and R implementation/docs. Therefore the earlier finding “no R test project found” applies only to the inspected `main` baseline; R test work now exists on the stacked feature branch.
- PR #27 changes `.github/workflows/client-ci.yml`; review its workflow filters and test commands together with client owners. Do not assume it has been merged into `main`.

### Cross-PR Actions evidence (not QA-06 results)
- PR #21 had an earlier successful Client CI run [42923668955](https://github.com/gfa437926-tech/metra2027/actions/runs/42923668955), but a later run [42923951902](https://github.com/gfa437926-tech/metra2027/actions/runs/42923951902) was queued at inspection.
- PR #22 had an earlier successful Backend build [42923764524](https://github.com/gfa437926-tech/metra2027/actions/runs/42923764524), but later run [42923926005](https://github.com/gfa437926-tech/metra2027/actions/runs/42923926005) was in progress.
- PR #23 had an earlier successful R workflow [42923702070](https://github.com/gfa437926-tech/metra2027/actions/runs/42923702070), but later run [42923751451](https://github.com/gfa437926-tech/metra2027/actions/runs/42923751451) was in progress.
- PR #27 Client CI [42923925042](https://github.com/gfa437926-tech/metra2027/actions/runs/42923925042) was pending at inspection.
- QA PR #24 still had no associated Actions run in the PR-run lookup; its commit status endpoint returned `pending` with zero statuses. Successful runs on other branches do not establish QA branch success.

## Recommended next execution sequence
1. Run existing CI commands on the QA branch and attach run URLs/results.
2. Add Angular unit/component tests and Flutter RTL/responsive/accessibility tests.
3. Add .NET test-server integration cases for JWT, exact station scope and documented error responses.
4. Add cross-layer UTC serialization/validation tests.
5. Add PostgreSQL integration tests for RLS, transactional workflow, concurrency and audit immutability.
6. Add R testthat fixtures and deterministic Climatol regression fixtures on the R feature branch, then verify the stacked PR against its base.
7. Add Playwright E2E + axe checks as release gates.
8. Reconcile the duplicate coordination files in PRs #21/#22 and review PR #27 CI path changes before integration.

## Change boundary
This QA branch changes documentation only. It does not alter Angular, Flutter, .NET, R implementation, SQL migrations, database configuration or database data. No PR is merged.


---

## CI follow-up — job-level status refresh (2026-11-10T23:32:18Z UTC)

The following records supersede the earlier queued/in-progress snapshot in the previous section. They are a point-in-time status review; no results are attributed to QA-06 itself.

| PR | Latest observed head | Latest observed run | Verified outcome at inspection |
|---|---|---|---|
| #21 Flutter | `3c5a2ee1f175e46bb903d2f6b30e816f3b45e8da` | [42924074199](https://github.com/gfa437926-tech/metra2027/actions/runs/42924074199) | In progress. Angular build, Flutter dependency resolution and `flutter analyze` passed; `flutter test` still running. |
| #22 Backend | `cfe43d00e729b6dbec76690a5734f8344dfe3abd` | [42923926005](https://github.com/gfa437926-tech/metra2027/actions/runs/42923926005) | Completed success. NuGet restore/audit, SQL authorization contracts, API build, Domain/API tests and Docker build passed. |
| #23 R/Climatol | `0c5ba868acf74fe7506d81d073f73c538ccec4d5` | [42924091642](https://github.com/gfa437926-tech/metra2027/actions/runs/42924091642) | In progress. Dependency setup completed; package check had not completed. Earlier run #42923751451 succeeded on an earlier SHA only. |
| #27 DevOps | `2fbce51f567ec7e3418f44e7ef5420f44bef9f1c` | [42924162203](https://github.com/gfa437926-tech/metra2027/actions/runs/42924162203) | Cancelled with no jobs. Earlier run #42922825265 succeeded on an earlier SHA only. |

### Additional interpretation
- PR #21's run #42923951902 was cancelled; its later run #42924074199 was the relevant current run at inspection. Do not report the cancelled run as a failing Flutter test.
- PR #22 has the strongest current positive evidence among these four branches because the completed success matches its observed head SHA.
- PR #23's previous successful run does not certify its newest commit.
- PR #27's earlier successful run does not certify its newest commit; the newest run was cancelled before jobs started.
- QA PR #24 remains open, Draft and unmerged. No Actions run was found for its current head `1a1c1f16e44e5b06aa1faf22f8061e11a42c1f10`. QA-06 did not run any test commands.

No implementation, workflow, schema, migration, data or deployment changes were made by QA-06 in this follow-up.


## Final observed parallel Actions outcomes (2026-11-10T23:33:00Z UTC)

This section supersedes the prior in-progress snapshot for the listed runs:

- PR #21 [Client CI #42924074199](https://github.com/gfa437926-tech/metra2027/actions/runs/42924074199) — **success** on head `3c5a2ee1f175e46bb903d2f6b30e816f3b45e8da`. Angular build and Flutter dependency resolution, analysis and tests passed. The Flutter test step includes the newly added UTC widget test in this PR head.
- PR #22 [Backend build #42923926005](https://github.com/gfa437926-tech/metra2027/actions/runs/42923926005) — **success** on head `cfe43d00e729b6dbec76690d0734f8344dfe3abd`. SQL authorization contracts, API build/tests and Docker image build passed.
- PR #23 [Climate Analytics R #42924091642](https://github.com/gfa437926-tech/metra2027/actions/runs/42924091642) — **success** on head `0c5ba868acf74fe7506d81d073f73c538ccec4d5`. Pinned Climatol fixture validation and R package check passed.
- PR #27 [Client CI #42924162203](https://github.com/gfa437926-tech/metra2027/actions/runs/42924162203) — **cancelled** on latest observed head `2fbce51f567ec7e3418f44e7ef5420f44bef9f1c`, with no jobs. Earlier success #42922825265 is for older head `8f1687246fd0f41a1d6de188eebd6beeb372e0a9`; it does not validate the latest head.
- QA PR #24 — no associated Actions run found for head `1a1c1f16e44e5b06aa1faf22f8061e11a42c1f10`; QA-06 did not run tests.

**QA conclusion:** latest observed heads for PRs #21, #22 and #23 have successful workflow evidence. PR #27 latest head remains unverified. None of these results constitutes test execution by QA-06 or validates QA PR #24. No application, workflow, database, migration or deployment changes were made by QA-06.


---

## QA-05 — Source-level station authorization and test audit (2026-11-10T23:34:44Z UTC)

### P1 — Review-queue authorization TOCTOU remains open
Current source path:
1. `ObservationQueueEndpoints` extracts actor ID from the verified JWT `sub`.
2. It calls `IStationAuthorizationService.HasStationPermissionAsync(userId, stationId, permission)` sequentially for `observation.review`, `observation.approve`, and `observation.return_for_correction`.
3. After one permission check succeeds, it calls `IObservationQueueService.GetSubmittedAsync(stationId, limit)`.
4. `SupabaseObservationQueueService` performs a separate service-role PostgREST SELECT filtered by station ID and submitted status. The queue read receives no actor ID and does not re-check the grant.

A permission revocation between steps 2 and 3 may leave an in-flight request able to return queue data after revocation. The station filter scopes rows but is not an actor authorization check under service-role access. This is a source-confirmed TOCTOU design flaw, not proof of unauthenticated access or a reproduced live exploit. The backend's B-013 design note independently identifies this issue and leaves implementation pending schema review/owner approval.

**Required fix:** an owner/schema-reviewed database RPC/read operation should accept the verified actor ID, exact station ID and bounded page size, and authorize + select in one atomic database operation with explicitly defined revocation/concurrency semantics. Do not implement SQL or alter schema until approval.

### P1/P2 — Missing queue endpoint integration evidence
- PR #22 adds submission request-guard tests for idempotency, type, payload and UTC offset.
- No `ObservationQueueEndpointTests.cs` exists at the inspected current PR #22 head.
- No endpoint integration test was found in the PR change set demonstrating missing-subject 401, cross-station 403, queue service not called after denial, or unavailable-service 503.
- No race test was found for permission revocation vs queue read.
- The test project references `Microsoft.AspNetCore.Mvc.Testing`; use a test server with fake authorization/queue services for endpoint behavior, then add isolated database integration tests only after the RPC/schema is approved.

### Decision workflow coverage still required
The decision endpoint performs a decision-specific API permission check and passes actor + station IDs to the service RPC. Source inspection does not establish that the database RPC rechecks permission atomically with the state transition. Required tests: queue reviewer without approve permission cannot approve; approve-only cannot return for correction; observation from station B cannot be decided through station A; concurrent conflicting decisions produce one valid transition and an auditable outcome.

### QA action
A review comment was submitted to [PR #22](https://github.com/gfa437926-tech/metra2027/pull/22) (review ID `5851183143`) anchored to commit `1ac10c4f083b5975bf1b95a456610725feecb704`. It records the TOCTOU finding, missing endpoint tests, atomic RPC recommendation and test cases.

No QA code, SQL, migration, database schema/data, or production resource was changed. QA-06 did not execute tests and does not claim the finding was exploited against a live system.


---

## QA-06 — CI freshness and migration trigger audit (2026-11-10T23:37:30Z UTC)

### Current PR-head evidence
- PR #22 Backend head `705668b9c3ff9f4011a622e5001099ca01f69931`: current-head Backend build succeeded. Source review confirms the review queue still performs a separate permission RPC followed by a service-role SELECT; no queue endpoint integration test file is present. B-013 remains unresolved.
- PR #21 Flutter head `58d1d6c3a83af7bce893f992dfeb1ea6fd10b412`: Client CI was pending at the time of snapshot. Earlier success belonged to an older SHA.
- PR #23 R head `42db1be81790d4dda47584019b729df8a1f53c07`: no workflow run found for the current head. Do not claim this head's tests passed.
- PR #27 DevOps head `71888fbecbaaf147db98aa632784b476fba047cd`: Client CI succeeded on current head.

### P2 — Backend CI does not watch Supabase migration path
`.github/workflows/backend-ci.yml` on main watches `database/migrations/**` and `database/tests/**`, but not `supabase/migrations/**`. Main currently contains five operational observation migration files in `supabase/migrations/`. A pull request changing only those files may therefore fail to trigger Backend build via paths. Add `supabase/migrations/**` to both push and pull_request filters, retaining the existing database paths. Add isolated migration validation/contract checks as appropriate. QA-06 recorded but did not modify the workflow.

### Client and R test coverage review
Flutter PR #21 tests cover bearer token forwarding, missing token, HTTPS-only origin, bounded queue limit, directory pagination/overflow and review UI behavior including UTC display normalization. These do not prove backend station isolation. Current head CI was pending.
R PR #23 testthat coverage includes symlink/path traversal, file type and directory boundaries, request validation, staged-copy integrity and provenance for successful/failed worker runs. No current-head CI result was available.

No QA-local test execution or application/workflow/SQL change was performed.


---

## QA-07 — Follow-up review of Backend endpoint tests and current CI (2026-11-11 UTC)

### PR #22 latest head
Latest inspected head: `8134c9e4546693d717a10329436d646b08dbb94f` (open Draft). Assistant 02 added `ObservationQueueEndpointTests.cs` with six WebApplicationFactory cases covering 401, invalid-limit 400, denied-scope 403/no queue read, fake Station A grant vs Station B request, unconfigured dependency 503, and queue-read failure 503.

**Coverage interpretation:** this closes the previously recorded *absence of endpoint-level queue tests* at source-presence level, but does not close B-013 or establish database-level station isolation. The cross-station test substitutes a fake authorization service. There are still no demonstrated integration tests for real station grants, permission revocation before read, concurrent read/revocation, or atomic authorization + queue selection.

### P1 — B-013 remains unresolved
At the latest inspected source, `ObservationQueueEndpoints` still calls `HasStationPermissionAsync(userId, stationId, permission)` and subsequently `GetSubmittedAsync(stationId, take)`. The service-role PostgREST queue read does not receive actor ID and does not atomically re-check the grant. This remains a source-confirmed TOCTOU design gap, not a reproduced live exploit. Keep P1 open until owner/schema-reviewed atomic read authorization and meaningful database integration/race tests are provided.

### P2 — backend CI migration path filter remains open
The current `.github/workflows/backend-ci.yml` inspected on PR #22 still omits `supabase/migrations/**` from both push and pull_request path filters while retaining `database/migrations/**` and `database/tests/**`. Changes limited to Supabase migration files may therefore fail to trigger Backend CI. QA did not modify the workflow.

### Current PR-head Actions snapshot
- PR #21 Flutter `58d1d6c3a83af7bce893f992dfeb1ea6fd10b412`: Client CI pending.
- PR #22 Backend `8134c9e4546693d717a10329436d646b08dbb94f`: Backend build in progress; no final outcome claimed.
- PR #23 R/Climatol `42db1be81790d4dda47584019b729df8a1f53c07`: Climate Analytics R success.
- PR #27 DevOps `71888fbecbaaf147db98aa632784b476fba047cd`: Client CI success.
- QA PR #24 `fd5e575c6818497bd82cbadc51eea61039b8e8a5`: no workflow run returned.

Cross-assistant CI results are not QA-06 test execution. QA-06 did not run tests locally. No code, workflow, SQL, migration, database or deployment changes were made by QA.


### QA-07 CI outcome correction — PR #22 exact latest head
The previously in-progress Backend build for PR #22 head `8134c9e4546693d717a10329436d646b08dbb94f` has now completed successfully: [Backend build run 42925182135](https://github.com/gfa437926-tech/metra2027/actions/runs/42925182135). This confirms the workflow completed successfully on that exact SHA, including the CI test job configured in `.github/workflows/backend-ci.yml`. It does **not** close the source-confirmed TOCTOU finding or substitute for DB revocation/race integration tests. QA-06 itself still did not run tests locally.
