# QA Assistant 06 — Change Log

Append-only log for QA work on METRA 2027. Entries are newest last; do not delete or rewrite earlier entries.

## QA-01 — Initial cross-stack inventory and traceability

- **Updated (UTC):** 2026-11-10T23:28:45Z
- **Status:** قيد التنفيذ
- **Branch:** `qa/metra-2027-test-coverage-audit`
- **PR:** [#24 — Draft](https://github.com/gfa437926-tech/metra2027/pull/24)
- **Baseline commit:** [c6ded6c18d1a7e33cb99c43fb0fc6d62161be528](https://github.com/gfa437926-tech/metra2027/commit/c6ded6c18d1a7e33cb99c43fb0fc6d62161be528)

### Files inspected
- `angular-app/package.json`, `angular-app/src/**`
- `.github/workflows/client-ci.yml`, `.github/workflows/backend-ci.yml`
- `backend/Metra.Api.Tests/**`, `backend/Metra.Api/**`
- `mobile/metra_mobile/pubspec.yaml`, `mobile/metra_mobile/test/**`
- `database/tests/**`, `supabase/migrations/**`
- Relevant API/security documentation and repository root inventory
- Requested coordination/specification paths were checked and not found on `main`: `واجهات/مهما.md`, `واجهات/تغيير.md`, `واجهات/README.md`, `docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md`.

### Files changed
- Added `docs/qa/REQUIREMENTS-TEST-MATRIX.md`.
- Added `docs/qa/QA-AUDIT-REPORT-2026-11-11.md`.
- Added this append-only log.
- Added `docs/progress/assistant-06.md`.

### Actually performed
- Inspected test and CI layout across the repository.
- Counted 20 .NET test source files, 3 Flutter test files and 12 SQL contract checks.
- Identified Angular build-only validation, missing R/Climatol test project on inspected main baseline, and missing E2E/accessibility test infrastructure in inspected paths.
- Created requirements-to-tests matrix and prioritized QA findings.
- Opened/updated Draft PR #24; no merge performed.

### Not performed
- Did not run npm, flutter, dotnet, PostgreSQL, shell contract tests or R tests in an execution environment.
- Did not add or execute new automated tests.
- Did not verify live cross-station authorization, UTC behavior, RTL/accessibility or end-to-end flows.
- Did not modify application logic, database schema/data, migrations or production deployment.
- Did not append to the shared Arabic coordination logs because those files were absent at the checked paths; no replacement files were fabricated.

### Test and GitHub Actions evidence
- **Local execution:** Not run; no execution environment for these toolchains was available in this session.
- **GitHub Actions for this audit commit:** No run result has been verified. Do not infer a pass from historical README references.
- **Historical CI references:** Repository documentation mentions runs dated 2026-11-04; these are not evidence for this branch/commit.

### Current task progress
- **Estimated completion:** 45%.
- **Calculation:** weighted QA work packages: repository inventory (15%) + traceability matrix (15%) + findings/report and Draft PR (10%) + dedicated tracking artifacts (5%) = 45%. Test execution (15%), test-suite implementation (20%), and cross-layer/security/UTC/E2E verification (20%) remain incomplete.
- **Remaining major work packages:** 3.
- **Next step:** obtain/restore the approved requirements and coordination documents, then run existing CI/test commands on this branch and record actual run URLs and outcomes before adding test suites.


## QA-02 — Cross-assistant PR dependency and CI evidence review

- **Updated (UTC):** 2026-11-10T23:30:26Z
- **Status:** قيد التنفيذ
- **Branch:** `qa/metra-2027-test-coverage-audit`
- **PR:** [#24 — Draft](https://github.com/gfa437926-tech/metra2027/pull/24)

### Files and resources inspected
- Re-fetched `docs/progress/assistant-06.md`, this changelog and `docs/qa/QA-AUDIT-REPORT-2026-11-11.md` from the QA branch before updating.
- Checked the four coordination/specification paths on both `main` and the QA branch; all remain absent.
- Reviewed changed-file lists and branch metadata for PRs #21, #22, #23 and #27, plus relevant workflow run metadata.

### Findings
1. PR #21 and PR #22 independently add `واجهات/مهما.md` and `واجهات/تغيير.md` against `main`, with different content. This creates a concrete integration/merge-conflict risk; consolidate the canonical files before merging both.
2. PR #23 is based on `work/climate-analytics-r-bootstrap`, not `main`; it is a stacked dependency. Its R test file exists on that branch, not in the main baseline used by the initial inventory.
3. PR #27 changes `.github/workflows/client-ci.yml`; workflow path filters and test commands should be reviewed jointly with the client owners.
4. Actions runs on other PR branches include successful runs for earlier SHAs, but latest heads were queued/in progress at inspection. These are not evidence for QA PR #24.
5. QA PR #24 head `7aa3ddee7bdd32f2eca009c797e27a0fb2c6d359` still has no associated workflow run in the PR-run lookup; commit status reports pending with zero statuses.

### Evidence links
- [PR #21](https://github.com/gfa437926-tech/metra2027/pull/21)
- [PR #22](https://github.com/gfa437926-tech/metra2027/pull/22)
- [PR #23](https://github.com/gfa437926-tech/metra2027/pull/23)
- [PR #27](https://github.com/gfa437926-tech/metra2027/pull/27)
- [PR #21 later queued Client CI](https://github.com/gfa437926-tech/metra2027/actions/runs/42923951902)
- [PR #22 later in-progress Backend build](https://github.com/gfa437926-tech/metra2027/actions/runs/42923926005)
- [PR #23 later in-progress R workflow](https://github.com/gfa437926-tech/metra2027/actions/runs/42923751451)
- [PR #27 pending Client CI](https://github.com/gfa437926-tech/metra2027/actions/runs/42923925042)

### Not performed
- No tests were executed by QA-06.
- No code, CI workflow, database, migration or shared coordination file was modified.
- No PR was merged.

### Progress
- **Estimated QA-06 completion:** 50%, weighted work-package method documented in `docs/progress/assistant-06.md`.
- **Remaining major work packages:** 3 — execute own CI/tests, implement missing suites, complete cross-layer verification and integration sign-off.


---

## QA-03 — Refresh parallel PR CI outcomes (2026-11-10T23:32:18Z UTC)

### Verified current PR/Actions evidence
- **PR #21 / Flutter:** current head at inspection was `3c5a2ee1f175e46bb903d2f6b30e816f3b45e8da`. Client CI run [42924074199](https://github.com/gfa437926-tech/metra2027/actions/runs/42924074199) was in progress. Angular build passed; Flutter dependency resolution and `flutter analyze` passed; `flutter test` had not completed at inspection. Earlier run [42923951902](https://github.com/gfa437926-tech/metra2027/actions/runs/42923951902) was cancelled; do not interpret cancellation as a test failure or pass.
- **PR #22 / Backend:** latest observed run [42923926005](https://github.com/gfa437926-tech/metra2027/actions/runs/42923926005) completed successfully on head `cfe43d00e729b6dbec76690a5734f8344dfe3abd`. Job steps passed NuGet restore/audit, authorization SQL contract checks, API build, Domain/API tests and Docker image build.
- **PR #23 / R:** latest head at inspection was `0c5ba868acf74fe7506d81d073f73c538ccec4d5`. Run [42924091642](https://github.com/gfa437926-tech/metra2027/actions/runs/42924091642) was in progress. Earlier run [42923751451](https://github.com/gfa437926-tech/metra2027/actions/runs/42923751451) completed successfully on earlier head `cb2fd0d486fcf22004edec100bde09f915e49b03`; it does not validate the latest head.
- **PR #27 / DevOps:** latest observed head `2fbce51f567ec7e3418f44e7ef5420f44bef9f1c`; Client CI run [42924162203](https://github.com/gfa437926-tech/metra2027/actions/runs/42924162203) was cancelled with no jobs. Earlier Client CI [42922825265](https://github.com/gfa437926-tech/metra2027/actions/runs/42922825265) succeeded on earlier head `8f1687246fd0f41a1d6de188eebd6beeb372e0a9`, not the latest PR head.
- **QA PR #24:** remains open, Draft, unmerged, mergeable at inspection. Latest QA head is `1a1c1f16e44e5b06aa1faf22f8061e11a42c1f10`. No workflow run is associated with this branch/PR; QA-06 has not run its own tests.

### QA interpretation
- PR #22 has a current successful Backend build at the observed head.
- PR #21's latest observed Flutter test step was still running; its result is unknown at this timestamp.
- PR #23's latest R workflow was still running; its result is unknown at this timestamp.
- PR #27's latest head has no completed successful Client CI run; its latest run was cancelled.
- None of these cross-assistant runs is a test run for QA PR #24.

### QA-06 work completed in this round
- Retrieved full run and job/step outcomes, not just run summary status.
- Corrected the previous round's queued/in-progress descriptions to final/observed statuses above.
- No source code, tests, workflows, database, migrations or shared coordination files were modified.

### Progress and remaining work
- QA-06 remains **50%** complete. The refreshed evidence review improves confidence but does not execute QA's own test plan or add missing suites.
- Three major work packages remain: own QA execution, missing test implementation, and cross-layer verification/integration sign-off.


## QA-04 — Finalize latest observed Actions outcomes (2026-11-10T23:33:00Z UTC)

- **PR #21 Flutter:** [Client CI #42924074199](https://github.com/gfa437926-tech/metra2027/actions/runs/42924074199) completed **success** on current observed head `3c5a2ee1f175e46bb903d2f6b30e816f3b45e8da`. Both Angular build and Flutter job passed; Flutter job explicitly passed `flutter pub get`, `flutter analyze` and `flutter test`. This run includes the newly added UTC widget test from that PR head.
- **PR #22 Backend:** [Backend build #42923926005](https://github.com/gfa437926-tech/metra2027/actions/runs/42923926005) completed **success** on observed head `cfe43d00e729b6dbec76690a5734f8344dfe3abd`; restore/audit, SQL authorization contracts, API build, Domain/API tests and Docker build passed.
- **PR #23 R/Climatol:** [Climate Analytics R #42924091642](https://github.com/gfa437926-tech/metra2027/actions/runs/42924091642) completed **success** on observed head `0c5ba868acf74fe7506d81d073f73c538ccec4d5`; dependency setup, pinned Climatol fixture version check and R package check passed.
- **PR #27 DevOps:** latest observed head `2fbce51f567ec7e3418f44e7ef5420f44bef9f1c`; [Client CI #42924162203](https://github.com/gfa437926-tech/metra2027/actions/runs/42924162203) completed **cancelled**, with no jobs. Earlier successful run #42922825265 is on older head `8f1687246fd0f41a1d6de188eebd6beeb372e0a9`; latest PR head remains unverified by a successful run.
- **QA PR #24:** remains open, Draft, unmerged. No QA branch workflow run was found; no QA-06 tests were executed.

### QA interpretation
- The current observed Flutter, Backend and R/Climatol branch heads now have successful Actions evidence.
- DevOps latest head remains unverified because its latest Client CI was cancelled; the older success must not be attributed to the latest head.
- These are results for the respective assistant branches, not for QA-06 or PR #24.
- QA-06 progress remains **50%**; the evidence refresh does not implement or execute QA's own outstanding test suites.


---

## QA-05 — Source-level authorization and endpoint-test audit (2026-11-10T23:34:44Z UTC)

### Files inspected on current PR #22 head
- `backend/Metra.Api/Features/Observations/ObservationQueueEndpoints.cs`
- `backend/Metra.Api/Security/StationAuthorizationService.cs`
- `backend/Metra.Api/Features/Observations/ObservationSubmissionEndpoints.cs`
- `backend/Metra.Api.Tests/Features/Observations/ObservationSubmissionRequestGuardTests.cs`
- `backend/Metra.Api.Tests/Features/Observations/ObservationDecisionRequestGuardTests.cs`
- `backend/Metra.Api.Tests/Metra.Api.Tests.csproj`
- `docs/backend/B-013-REVIEW-QUEUE-TOCTOU-DESIGN.md`
- `docs/backend/API-BACKEND-AUDIT-2026-11-11.md`

### Confirmed finding — P1 authorization TOCTOU
The current queue endpoint calls `HasStationPermissionAsync(userId, stationId, permission)` for one of three permissions, then calls `GetSubmittedAsync(stationId, take)`. The queue service executes a separate PostgREST SELECT using the service-role credential and does not receive `userId`. Therefore the authorization decision and data read are not one atomic operation. A grant revoked after the authorization RPC but before the SELECT may still allow the in-flight request to return submitted rows. The queue SELECT filters by the requested station ID and submitted status, but that filter is not an actor authorization check when service-role access is used.

This is a source-confirmed authorization TOCTOU window, not proof of unauthenticated access or a demonstrated exploit against a live database. B-013's own design document records the same gap and leaves remediation pending schema review/owner approval.

### Confirmed test gap
- PR #22 adds `ObservationSubmissionRequestGuardTests.cs`, which covers request-shape validation and UTC offset rejection.
- No `ObservationQueueEndpointTests.cs` exists at the current PR #22 head.
- No endpoint-level evidence was found in the inspected PR changes proving the queue returns 401 for missing subject, 403 for a user scoped to another station, and that the queue service is never invoked when authorization fails.
- No race/concurrency test was found for queue read vs grant revocation.
- The test project references `Microsoft.AspNetCore.Mvc.Testing`, so test-server integration infrastructure is available as a dependency; actual configured integration fixtures/routes still need inspection and implementation.

### Additional decision-endpoint note
The observation decision handler explicitly checks a decision-specific permission before calling its service, and the service RPC receives user ID and station ID. However, this source inspection alone does not prove the database RPC atomically revalidates that permission while changing the observation state. Tests must cover reviewer-without-approve, reviewer-without-return, wrong-station observation ID, and concurrent decisions.

### QA action
- Submitted a review comment on PR #22 (review ID `5851183143`) anchored to head `1ac10c4f083b5975bf1b95a456610725feecb704`, identifying the P1 TOCTOU issue, missing queue endpoint tests, recommended atomic actor+station RPC and required concurrency cases.
- No code or SQL was changed by QA-06. No schema/RPC remediation was attempted because the backend design explicitly requires schema review and owner approval first.

### Evidence and status
- [PR #22 review](https://github.com/gfa437926-tech/metra2027/pull/22)
- [B-013 TOCTOU design](https://github.com/gfa437926-tech/metra2027/blob/work/backend-api-audit-assistant-2/docs/backend/B-013-REVIEW-QUEUE-TOCTOU-DESIGN.md)
- QA-06 did not run tests. This is a static source review finding; do not report it as a reproduced exploit.
- QA-06 estimated completion remains 50%; source review and review comment are evidence gathering, not test implementation/execution.


---

## QA-06 — Cross-PR CI freshness and migration trigger audit (2026-11-10T23:37:30Z UTC)

### Current head status snapshot
- PR #22 Backend head `705668b9c3ff9f4011a622e5001099ca01f69931`: Backend build completed successfully on this head. The review-queue endpoint source remains the two-call permission-check + service-role SELECT path; no queue endpoint integration test file is present in this head's changed-file set. B-013 remains open.
- PR #21 Flutter head `58d1d6c3a83af7bce893f992dfeb1ea6fd10b412`: Client CI is pending at the time of this check. Earlier success on an older SHA must not be presented as validation of this current head.
- PR #23 R/Climatol head `42db1be81790d4dda47584019b729df8a1f53c07`: no workflow run was returned for this head. Its new workflow is defined for R package checks, but this head's PR is stacked against `work/climate-analytics-r-bootstrap`; the run is not yet evidenced on the current head.
- PR #27 DevOps head `71888fbecbaaf147db98aa632784b476fba047cd`: Client CI completed successfully on this head.

### New CI trigger finding — backend migration path filter (P2)
The baseline `.github/workflows/backend-ci.yml` path filters include `database/migrations/**` and `database/tests/**`, but omit `supabase/migrations/**`. The main branch currently contains five operational observation migration files under `supabase/migrations/` (submission, client-access denial, FK indexes, review decision, and decision null-validation hardening). Therefore a PR that changes only one of those Supabase migration files may not trigger Backend build via the path filter. This is a CI coverage/trigger gap; it does not prove the SQL itself is incorrect.

Recommended action: add `supabase/migrations/**` to both push and pull_request path filters, and add appropriate migration contract checks or isolated database migration validation. Keep `database/migrations/**` as well; do not replace it. This is a DevOps/backend CI change, not applied by QA-06.

### Flutter test observations
Current PR #21 adds API-client tests for bearer-token forwarding, HTTPS-only API origin, missing-token rejection, bounded queue limit, station directory pagination and overflow; widget tests cover Arabic review queue rendering, UTC-normalized display of an offset timestamp, empty state and safe network failure messaging. These are useful client-level tests but do not validate server-side station authorization or actual API/database integration. The current PR #21 head CI was pending during this snapshot.

### R/Climatol test observations
Current PR #23 adds testthat coverage for symlink/path traversal boundaries, input/output directory separation, input file type checks, request variable/year validation, staged input copies, provenance hashes and failed-run provenance. These are useful service-level tests. No current-head CI run was available in the snapshot, so test success is not asserted here.

### Evidence limits
- QA-06 still has not executed local test commands.
- PR #22 success is CI evidence for that backend head, not proof that the queue authorization TOCTOU is fixed.
- PR #21 pending and PR #23 without a current-head run remain unverified at this snapshot.
- No app code, workflow, SQL, migration, database, or deployment was changed by QA-06.


---

## QA-07 — Recheck Backend queue tests, cross-PR CI and migration triggers (2026-11-11 UTC)

### PR #22 — new endpoint tests found; P1 remains open
- Latest PR #22 head at inspection: `8134c9e4546693d717a10329436d646b08dbb94f` (open, Draft).
- Added `backend/Metra.Api.Tests/Features/Observations/ObservationQueueEndpointTests.cs` (198 lines). Static review confirms six test cases: unauthenticated 401; invalid limit 400; denied station scope 403 with queue call count zero; Station B request denied when fake grant is for Station A; unconfigured dependency 503; queue-read failure 503.
- These are useful WebApplicationFactory endpoint tests, but the Station A/B case uses a fake authorization service and does not exercise database grants or real PostgREST isolation. No revoke-before-read or concurrent read/revocation test was added.
- Re-read `ObservationQueueEndpoints.cs` at the current head. It still calls permission RPC(s) first, then calls `GetSubmittedAsync(stationId, take)`; the service-role SELECT still does not receive actor ID or re-check permission atomically. P1 B-013 remains open. No SQL/schema change was made by QA.
- Current Backend build for head `8134c9e...` was **in progress** at inspection; do not infer test success from the earlier successful SHA or from the existence of test source.

### Current PR-head Actions snapshot
- PR #21 Flutter head `58d1d6c3a83af7bce893f992dfeb1ea6fd10b412`: Client CI pending.
- PR #22 Backend head `8134c9e4546693d717a10329436d646b08dbb94f`: Backend build in progress.
- PR #23 R/Climatol head `42db1be81790d4dda47584019b729df8a1f53c07`: Climate Analytics R completed success.
- PR #27 DevOps head `71888fbecbaaf147db98aa632784b476fba047cd`: Client CI completed success.
- QA PR #24 head `fd5e575c6818497bd82cbadc51eea61039b8e8a5`: no PR-triggered workflow run returned.

### P2 migration-trigger finding revalidated
- Re-read `.github/workflows/backend-ci.yml` at PR #22's latest head. Both push and pull_request path filters still include `database/migrations/**` and `database/tests/**`, but omit `supabase/migrations/**`.
- P2 remains open; QA did not edit another assistant's workflow.

### Boundaries and progress
- QA performed static source review and GitHub Actions metadata review only; no local tests were run by QA.
- No application code, CI workflow, SQL, migration, database, deployment or merge was changed.
- QA-06 remains estimated at 50%; three major work packages remain. Adding tests in the Backend PR is progress by Assistant 02, not completion of QA-06's own test implementation/execution work.
