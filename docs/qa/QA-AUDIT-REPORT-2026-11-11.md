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
