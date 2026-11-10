# METRA 2027 — Cross-assistant PR evidence register

- Audit timestamp: 2026-11-10T23:31:57Z (UTC)
- Repository: `gfa437926-tech/metra2027`
- Purpose: preserve a cross-assistant evidence index for requirements traceability.
- Critical distinction: PR descriptions and branch files are **proposed branch evidence**, not evidence that the feature is present on `main`, deployed, or accepted. All PRs listed below were open Draft/WIP when inspected unless explicitly stated otherwise.
- This register is a triage of PR metadata, changed-file lists, descriptions, and selected Actions run records. It is not a complete code review or runtime certification.

## PR evidence

| PR | Owner lane | Branch / latest inspected head | Changed-file scope / claims | Verification evidence checked | Traceability treatment |
|---|---|---|---|---|---|
| [#19](https://github.com/gfa437926-tech/metra2027/pull/19) | UI catalogue / requirements | `docs/metra-all-ui-specification` / `e54d136af32107b6f6657eb55d971d7518ab4b18` | UI-01–UI-15 catalogue, design-system docs, Arabic coordination files; PR states 16 UI documents and explicitly says catalogue is not proof of implementation. | PR metadata and description only in this pass. | Candidate requirements source; owner approval and reconciliation with other specification PRs required. |
| [#20](https://github.com/gfa437926-tech/metra2027/pull/20) | Electronic paper/mechanical-record auditor | `work/electronic-record-auditor-audit` / `5056ac2d20e8f20d470efa70ebdfffdf27ebb2ff` | Documentation-only audit/design: immutable source image, OCR/CV provenance, mechanical chart digitization, read-only comparison, human approval, test matrix. | PR says no software tests or Actions; no executable code. | Requirements/design evidence only; implementation remains unverified. |
| [#21](https://github.com/gfa437926-tech/metra2027/pull/21) | Flutter | `assistant-3/flutter-mobile-audit` / `3c5a2ee1f175e46bb903d2f6b30e816f3b45e8da` | Changes `observation_review_screen.dart`, adds `observation_review_screen_test.dart`, assistant report and coordination files; claims UTC-only display and offset regression test. | [Client CI #42923668955](https://github.com/gfa437926-tech/metra2027/actions/runs/42923668955) succeeded on earlier SHA `9fa9b04e33a7ec914ffd0b2cf619f94c1a105868`; PR says the new UTC test was added after that run and remains unverified by that run. | Flutter UTC correction is pending branch-head CI; do not mark the new test as passed from the older run. |
| [#22](https://github.com/gfa437926-tech/metra2027/pull/22) | ASP.NET Core / API | `work/backend-api-audit-assistant-2` / `cfe43d00e729b6dbec76690a5734f8344dfe3abd` | Observation submission endpoint and request-guard test, backend audit and progress docs; claims strict UTC boundary and non-zero-offset regression coverage; reports review-queue TOCTOU concern. | [Backend build #42922191087](https://github.com/gfa437926-tech/metra2027/actions/runs/42922191087) succeeded on `a91d73eef8ef78e68656ea96d67a25f833b857f0`; [#42922249720](https://github.com/gfa437926-tech/metra2027/actions/runs/42922249720) succeeded on `954fb5873450d417ef340bd3a092a00686b035ad`. Neither run is on the latest PR head. | API UTC enforcement is candidate evidence; confirm latest-head CI and review TOCTOU finding before acceptance. |
| [#23](https://github.com/gfa437926-tech/metra2027/pull/23) | R / Climatol | `work/climate-analytics-r-hardening` / `0c5ba868acf74fe7506d81d073f73c538ccec4d5` | R worker, SHA-256 input integrity, provenance manifest, worker tests and Climatol smoke test. | [Climate Analytics R #42922431783](https://github.com/gfa437926-tech/metra2027/actions/runs/42922431783) succeeded on earlier SHA `c9d26c55d0743ea96830ba1df157f2cc05c7455f`; PR says the latest fixture smoke test is pending. | R implementation/test evidence exists on branch; latest smoke-test and scientific validation remain pending. |
| [#24](https://github.com/gfa437926-tech/metra2027/pull/24) | QA / testing | `qa/metra-2027-test-coverage-audit` / `1a1c1f16e44e5b06aa1faf22f8061e11a42c1f10` | QA audit, requirements-to-tests matrix, QA progress and append-only log; documentation-only. | PR says no tests executed by QA; no associated Actions run in its PR-run lookup; no pass/fail claim. | Useful test inventory proposal; must be reconciled with actual tests and latest workflow runs. |
| [#25](https://github.com/gfa437926-tech/metra2027/pull/25) | Meteorological science | `review/meteorological-science-audit` / `9d24a1b78cf727c8846dbd77d46d8f34114c2497` | Scientific audit and decision/open-question docs; coordination files. | PR says no tests or Actions in this round; no application code or DB changes. | Records **reported** risks for owner validation: validators not called by operational submission path; Angular/.NET RH min/max mismatch; undocumented daily `HH.d` semantics; need source/quality flags. These are not independently reproduced by assistant 10 yet. |
| [#26](https://github.com/gfa437926-tech/metra2027/pull/26) | Database engineering | `work/database-engineering-audit` / `8f1a7f57b9b9115a89485a784af437604a3b32ef` | Repository-only data model proposal and DB audit; proposed SQL intentionally outside active migrations. | PR reports no tests/Actions, no Supabase access, and no DB/schema/data change. | Design proposal only; no migration or schema change is approved by this register. |
| [#27](https://github.com/gfa437926-tech/metra2027/pull/27) | DevOps / CI | `assistant-9/devops-ci-hardening` / `7740a947a1fde0ae5f28069ebd286508e6cfaf1e` | Client CI workflow, DevOps audit, assistant progress and changelog; claims locked npm/Flutter dependencies and reproducible CI. | [Client CI #42922825265](https://github.com/gfa437926-tech/metra2027/actions/runs/42922825265) succeeded on earlier SHA `8f1687246fd0f41a1d6de188eebd6beeb372e0a9`; not latest PR head. | CI improvements are candidate branch evidence; validate latest-head workflow and path filters before acceptance. |
| [#28](https://github.com/gfa437926-tech/metra2027/pull/28) | System integration | `assistant-12/system-integration-audit` / `7e40dd77bd8a988734f9a3806b9048f49bb124e9` | Architecture/data-flow and integration/contract matrices, coordination docs and progress report. | PR says static source inspection only; no automated tests or Actions for that round; no production E2E. | Source-level integration evidence only; production host, authenticated runtime and mock/demo-data inventory remain open. |
| [#30](https://github.com/gfa437926-tech/metra2027/pull/30) | Security | `security/initial-hardening-audit` / `2706deb0cccc0ca5c1aeaab5b741a3c89f75719b` | Security audit, `.gitignore`, client CI, API security headers and authentication test; PR says rate limits, body ceilings, CSP/session-storage and host filtering remain open. | PR description says Client CI and Backend build were in progress at last check; no live penetration test or production auth test. | Static review and branch hardening only; security controls require latest-head CI and threat-specific verification. |
| [#31](https://github.com/gfa437926-tech/metra2027/pull/31) | Independent final audit | `audit/assistant-13-independent-final-review` / `c855ecef7455ab9be5d80ccd9254c8eb2f67b73d` | Independent-audit progress and changelog only. | PR states substantive audit blocked pending reviewable outputs from assistants 1–12; no source diffs, test suites or Actions verified in that round. | Not an implementation or release verdict; audit remains blocked. |

## Cross-cutting requirements implications

1. **UTC-only contract:** Flutter (#21) and API (#22) both report changes, but the cited successful CI runs are on earlier SHAs than their inspected PR heads. Treat UTC as a project decision with incomplete branch-head verification, not a fully proven end-to-end property.
2. **Scientific validation:** PR #25 reports a potential operational validation gap and a humidity-range mismatch. The finding must be checked against the exact current endpoint, validators, Angular form rules and tests before it becomes a confirmed defect.
3. **Flutter parity:** PR #21's file list is limited to observation review and its test; it does not establish full parity for all report, maintenance, profile, support or alert screens.
4. **Climatol:** PR #23 includes executable R worker and test files, but the latest fixture smoke test is reported pending and scientific acceptance of METRA production/reference data is not claimed.
5. **QA/CI:** PR #24 is an audit/matrix, not a test execution result. CI success on another PR or earlier SHA must not be attributed to QA or to the latest branch head.
6. **Database safety:** PR #26 is proposal-only. This register authorizes no SQL, migration, RLS, seed, Supabase setting or data operation.
7. **Security and deployment:** PR #30 is static review and hardening, not penetration testing or production authentication proof. PR #27's earlier successful client CI does not prove the current head or deployment readiness.
8. **Coordination-file conflicts:** PR #21, #22, #25, #26, #28 and #30 each carry their own versions of shared Arabic coordination files. PR #24 explicitly warns that histories differ. Consolidate histories deliberately; never merge by blindly accepting one branch's copy over another.

## Acceptance rules

- Keep the baseline matrix statuses for `main` separate from proposed branch evidence until each PR is reviewed and merged.
- For every CI claim, record workflow name, run URL, conclusion and exact tested SHA.
- A successful run on an ancestor commit does not certify a later commit that added or changed tests.
- A PR description is an owner-reported claim, not independent proof.
- Do not infer implementation absence from one assistant's limited source inventory; record scope and inspection limits.
- No PR in this register is approved or merged by this document.


## Live snapshot refresh and source-level verification — 2026-11-10T23:35:51.758Z

This section supersedes earlier PR-head and workflow snapshots above where values differ. All PRs below remained open Draft/WIP and unmerged at the time of this refresh.

### Current PR heads and CI status

| PR | Current inspected head | Latest associated run found for that exact head | Status at refresh | Interpretation |
|---|---|---|---|---|
| #21 Flutter | `aedfb6fbebc1c7d6df59dd7b29e9de392072fc53` | [Client CI #42924486755](https://github.com/gfa437926-tech/metra2027/actions/runs/42924486755) | In progress | Previous success #42924074199 was for older head `3c5a2ee1...`; it does not certify this head. |
| #22 Backend | `35364375dfa497ce64579ef9053f0a0a562ce034` | [Backend build #42924494660](https://github.com/gfa437926-tech/metra2027/actions/runs/42924494660) | In progress | Previous success #42923926005 was for older head `cfe43d00...`; this head is not yet certified. |
| #23 R / Climatol | `0915fe7b11b36b3e34d4c9189ba734be7c6a68a1` | [Climate Analytics R #42924449733](https://github.com/gfa437926-tech/metra2027/actions/runs/42924449733) | In progress | Previous success #42924091642 was for older head `0c5ba868...`; this head is not yet certified. |
| #24 QA | `1e1704300808c9fdf901a0103bf04cc924120b83` | No associated workflow run returned | No run found | QA report/matrix remain documentation artifacts; QA did not execute tests. |
| #27 DevOps | `a484aca09174ffa4f6048423471806a76fba712b` | [Client CI #42924526165](https://github.com/gfa437926-tech/metra2027/actions/runs/42924526165) | Cancelled; no jobs | No test result. Earlier success #42922825265 is for an older SHA. |
| #28 Integration | `387747eaf47814689d6e6facaf0a74301864e473` | No associated workflow run returned | No run found | Static source inventory only; no runtime E2E evidence. |
| #30 Security | `9689ab821a2dfb8200ded46cf30c33ed8068208f` | [Backend build #42924494881](https://github.com/gfa437926-tech/metra2027/actions/runs/42924494881); [Client CI #42924494937](https://github.com/gfa437926-tech/metra2027/actions/runs/42924494937) | Backend **failure**; Client CI **cancelled** | Backend restore/audit, SQL contract checks and API build passed; the **Run domain and API tests** step failed; Docker image step was skipped. Angular build and npm audit passed, but Flutter action was cancelled before pub get/analyze/test. Root cause of the .NET test failure was not established in this review. |

Other inspected PRs: #25 scientific review, #26 database engineering, and #31 independent final audit remained open Draft/WIP and unmerged. Their PR descriptions and scope are recorded above; this refresh did not treat them as executable test evidence.

### Confirmed source-level finding — review queue authorization TOCTOU

Assistant 10 independently inspected the `main` source files:
- `backend/Metra.Api/Features/Observations/ObservationQueueEndpoints.cs`
- `backend/Metra.Api/Security/StationAuthorizationService.cs`
- `backend/Metra.Api/Program.cs`

The endpoint obtains actor identity from the validated `sub` claim, checks up to three station permissions through `HasStationPermissionAsync`, then calls `GetSubmittedAsync`. That second operation performs a separate service-role PostgREST SELECT filtered by station and submitted status; it does not receive the actor ID and does not repeat authorization atomically. The permission RPC and row read are therefore separate operations, and a permission revocation can occur between them. This confirms the source-level TOCTOU condition described in PR #22's B-013 design. It does **not** establish unauthenticated access, nor does it prove exploitation has occurred. The proposed atomic RPC/read model remains a design only and requires schema review, owner approval, concurrency tests and implementation.

### Confirmed integration boundaries from source inventory

Assistant 10 reviewed `docs/architecture/CLIENT-DATA-SOURCE-INVENTORY.md` on PR #28. Its static findings distinguish:
- Angular hourly/daily: API submission exists in source, but visible history/drafts/previews are partly local; runtime persistence remains unverified.
- Angular phenomena input/list: local in-memory timer/list; no API persistence/read wiring evidenced.
- Angular rainfall, climate, soil temperature and agriculture: preview/local flows; no API persistence evidenced.
- Angular monthly/annual reports: no API read source evidenced; empty station arrays/placeholders/local criteria.
- Angular dashboard: reads `localStorage.currentUser`; not proof of authenticated Supabase identity or server sign-out.
- Flutter: station directory and observation review call API methods; no observation-entry screen invoking the submit method was found; reports remain unavailable/unconnected.
- R/Climatol and paper-register image auditor: proposed flows only in the integration audit; not evidenced as connected runtime services.

These are source-inventory classifications, not live runtime tests.

### QA baseline findings and interpretation

PR #24's QA report records a baseline inventory of 20 .NET test source files, 3 Flutter test files and 12 SQL shell contract checks; Angular baseline CI is build-only, and no browser E2E/accessibility runner or cross-layer UTC suite was identified. QA explicitly did not run test commands. A test file's presence does not prove that it passes or adequately covers a requirement.

### Additional security CI interpretation

For PR #30's exact head, Backend build #42924494881 failed specifically at the `Run domain and API tests` step after API build and SQL contract checks passed. Client CI #42924494937 was cancelled in the Flutter job before Flutter dependency resolution, analysis or tests; Angular build and dependency audit passed. Do not classify the cancelled Flutter step as a test failure or the passed Angular job as overall client CI success.

### Review limitations

- No local toolchain tests, live API calls, authenticated E2E, penetration test or production assessment were run by assistant 10.
- The latest-head workflow states are a point-in-time snapshot and may change; refresh before any merge decision.
- No application code, SQL, migrations, Supabase configuration, production data or database were changed.
- No PR was approved, marked ready, or merged by this register.


### PR #30 Backend failure — job log diagnosis (2026-11-10T23:36:55.798Z)

The failed job log for [Backend build #42924494881](https://github.com/gfa437926-tech/metra2027/actions/runs/42924494881) was retrieved and inspected.

- Test result: **8 failed, 226 passed, 0 skipped, 234 total**.
- The failed cases include `ApiAuthenticationTests.Every_authority_access_endpoint_requires_authentication`: expected HTTP 401 Unauthorized, received HTTP 429 Too Many Requests.
- `Readiness_endpoint_is_anonymous_but_fails_when_server_dependencies_are_missing`: expected HTTP 503 Service Unavailable, received HTTP 429 Too Many Requests.
- The security branch's `Program.cs` adds a global fixed-window rate limiter and a named readiness policy; the pipeline calls `UseRateLimiter()`. The tests issue multiple requests through the test host and currently observe 429 before the expected endpoint/authentication outcome.
- This establishes a **test/limiter interaction and status-contract regression** in the current PR #30 head. It does not by itself prove the production limiter's partitioning is unsafe. The precise fix should be made by the security/backend owners: isolate or disable limiter state in tests where appropriate, explicitly apply the readiness policy as intended, and retain separate tests that verify real 429 behavior without masking 401/503 endpoint contracts.
- API build and preceding SQL authorization contract checks passed in that run; Docker image build was skipped after test failure.
- The client workflow was cancelled in the Flutter setup step; Angular build and npm audit passed, but Flutter pub get/analyze/test were skipped.
- Assistant 10 did not modify PR #30 or rerun its workflow. The failure is recorded for the owning assistants to resolve.


## Second live snapshot — 2026-11-10T23:38:13.441Z (supersedes prior latest-head table)

The owning assistants pushed additional commits during this review. Latest PR heads and exact-head Actions lookup now show:

| PR | Latest inspected head | Workflow run(s) for exact head | Current observed state |
|---|---|---|---|
| #21 Flutter | `58d1d6c3a83af7bce893f992dfeb1ea6fd10b412` | [Client CI #42924658140](https://github.com/gfa437926-tech/metra2027/actions/runs/42924658140) | Pending |
| #22 Backend | `e771f056835a17c894ef01542f7b55fd0aa2ce4e` | [Backend build #42924878526](https://github.com/gfa437926-tech/metra2027/actions/runs/42924878526) | In progress |
| #23 R / Climatol | `42db1be81790d4dda47584019b729df8a1f53c07` | [Climate Analytics R #42924761774](https://github.com/gfa437926-tech/metra2027/actions/runs/42924761774) | In progress |
| #24 QA | `fd5e575c6818497bd82cbadc51eea61039b8e8a5` | No associated workflow run returned | No run found |
| #27 DevOps | `71888fbecbaaf147db98aa632784b476fba047cd` | [Client CI #42924596524](https://github.com/gfa437926-tech/metra2027/actions/runs/42924596524) | Success — Angular build and Flutter dependency resolution, analyze and tests all passed |
| #28 Integration | `9b3ad187de7cbbf861dd7b091c193172e5a77ea9` | No associated workflow run returned | No run found; static source audit only |
| #30 Security | `32e5ecce8db2ad8899a49174d9d628fa1faf193b` | [Backend build #42924701188](https://github.com/gfa437926-tech/metra2027/actions/runs/42924701188); [Client CI #42924701234](https://github.com/gfa437926-tech/metra2027/actions/runs/42924701234) | Both **success** |

### Resolution evidence for PR #30's earlier CI failure

The previous head `9689ab82...` failed 8/234 tests because rate-limiter behavior caused 429 responses where tests expected 401/503. The owner then updated the branch; the current PR body states that the shared anonymous bucket issue was corrected by applying the global limiter to authenticated subjects and a separate readiness-only anonymous policy.

For the new head `32e5ecce...`:
- Backend build #42924701188: restore/NuGet audit, all SQL authorization contract checks, API build, all domain/API tests, and Docker image build passed.
- Client CI #42924701234: Angular `npm ci`, high/critical npm audit, Angular build, Flutter dependency resolution, `flutter analyze`, and `flutter test` all passed.
- These are verified successes on the exact current PR #30 head, unlike the earlier failed/cancelled runs. This validates the CI scope executed, not live production security or penetration resistance.

PR #27's current head also now has successful Angular and Flutter CI. PRs #21, #22 and #23 still have newer pending/in-progress runs; prior successful SHAs must not be substituted for those runs. No workflow run was found for QA #24 or integration #28 at this snapshot.

All PRs remain open Draft/WIP and unmerged in the latest PR inventory. No assistant 10 approval or merge action was performed.


## Final head movement check — 2026-11-10T23:39:25.062Z

PR #22 advanced again after the previous snapshot:
- Current PR #22 head: `efa5870e555d4f74584e44bd439002daf784afa3` (updated `2026-11-10T23:39:00Z`).
- An exact-head Actions lookup returned no associated workflow run at this check. The previously observed run #42924878526 belongs to earlier head `e771f056...` and must not be attributed to this newer head.
- PR #21 run #42924658140 remains `pending` on head `58d1d6c3a83af7bce893f992dfeb1ea6fd10b412`.
- PR #23 run #42924761774 remains `completed` on head `42db1be81790d4dda47584019b729df8a1f53c07`.
- PR #27 and #30 latest successful runs remain the verified results in the preceding snapshot.

This illustrates why CI evidence is stored against exact commit SHAs rather than PR numbers alone.

### Completion update — R/Climatol and Flutter pending (2026-11-10T23:39:35.388Z)

- PR #23 current head `42db1be81790d4dda47584019b729df8a1f53c07`: [Climate Analytics R #42924761774](https://github.com/gfa437926-tech/metra2027/actions/runs/42924761774) completed **success** on that exact SHA.
- PR #21 current head `58d1d6c3a83af7bce893f992dfeb1ea6fd10b412`: [Client CI #42924658140](https://github.com/gfa437926-tech/metra2027/actions/runs/42924658140) remained **pending** at the latest check.
- PR #22 current head `efa5870e555d4f74584e44bd439002daf784afa3`: no associated workflow run was returned for this exact SHA. Earlier Backend build #42924878526 belongs to previous head `e771f056...`.
