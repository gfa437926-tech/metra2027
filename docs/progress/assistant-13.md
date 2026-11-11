# Assistant 13 — Independent Final Audit Progress

**Task:** M13 — Independent final audit of METRA 2027  
**Status:** In progress — preliminary independent review  
**Updated:** 2026-11-10T23:37:42.555Z (UTC)  
**Repository:** `gfa437926-tech/metra2027`  
**Branch:** `audit/assistant-13-independent-final-review`

## Current-round result

This is an administrative baseline only. The independent technical audit has **not** started because the agreed entry condition was that reviewable outputs from assistants 1–12 must be available. The current repository does contain a set of open PRs, but the required coordination files could not be read from `main`, and the PR descriptions are not substitutes for source-level verification.

## Evidence inspected

### Files requested at the audit entry point

Attempted to fetch each file from `main`; all returned GitHub Contents API 404 (not found):

- `واجهات/مهما.md`
- `واجهات/تغيير.md`
- `واجهات/README.md`

These paths therefore were **not** inspected. This report does not assume their absence from every feature branch; PR #29 and other PR descriptions indicate that some branches introduce coordination files.

### GitHub pull-request inventory

Queried open PRs in the repository. The returned inventory contained 20 open PRs:

- #1 — identity migration and station catalogue foundation
- #11 — maintenance/support domain foundations
- #12 — remove exact legacy duplicates
- #13 — consolidated repository audit evidence
- #14 — independent hourly/daily UI reimplementation
- #15 — Flutter observation module catalogue
- #16 — Flutter observation modules rebase
- #17 — complete page and test specification
- #18 — R/Climatol worker and climatology summaries
- #19 — Arabic METRA UI catalogue
- #20 — electronic paper-record auditor
- #21 — Flutter mobile audit
- #22 — Backend audit and UTC enforcement
- #23 — R/Climatol provenance and integrity
- #24 — QA test coverage audit
- #25 — scientific meteorological audit
- #26 — database engineering audit
- #27 — DevOps/client CI audit
- #28 — system integration audit
- #29 — requirements traceability baseline
- #30 — security audit and hardening

The inventory is discovery evidence only. PR descriptions, claimed CI results, and author summaries have **not** been accepted as proof that the implementation works. Individual diffs, commit ancestry, workflow runs, test logs, and cross-branch conflicts remain to be examined.

## Work performed in this round

- Confirmed the repository is `gfa437926-tech/metra2027` and its default branch is `main`.
- Created the isolated audit branch `audit/assistant-13-independent-final-review` from `main`.
- Attempted to read the three required coordination files; recorded their 404 responses.
- Enumerated 20 open PRs and captured their numbers and titles for the audit queue.
- Created this independent progress report and an append-only assistant-13 changelog.

## Work not performed

- No source-code review or implementation verification.
- No PR diff review, branch comparison, merge-conflict analysis, or commit-by-commit audit.
- No GitHub Actions run inspection or test execution.
- No Angular/Flutter/.NET/R compatibility, authorization, UTC, database-contract, or immutable-record conclusion.
- No database access or modification, migration, merge, or deployment.

## Tests and GitHub Actions

- Tests executed in this round: **none**.
- GitHub Actions runs verified in this round: **none**.
- CI/test status: **not assessed**. Results quoted in PR descriptions remain unverified until the relevant run and commit are inspected.

## Files

**Files examined:** the three requested coordination paths were attempted but unavailable on `main`; open PR metadata for 20 PRs was queried. No application source files were examined.

**Files created/modified by this assistant:**  
- `docs/progress/assistant-13.md` (created)
- `docs/changelog/assistant-13.md` (created)

No shared coordination file or other assistant's report was modified.

## Progress calculation

**M13 audit completion: 0%.**  
Method: 12 substantive audit workstreams are defined by the assignment (deliverable evidence; PR/branch conflicts; Angular; Flutter; .NET/API; R; security/authorization; database/contracts; UTC; original-record integrity; tests/CI; release recommendation). None has completed source-level evidence verification yet. Repository discovery and report setup are administrative preparation and do not count as completed audit work.

**Remaining:** 12 substantive audit workstreams.

## Blocker and next step

**Blocker:** required reviewable results from assistants 1–12 are not yet assembled in a reliable, accessible baseline; the three entry-point files are not readable from `main`.

**Next:** inspect the report and implementation branches/PRs for assistants 1–12, starting with their latest head commits and associated CI evidence; establish the canonical integration baseline, then begin evidence-based review workstream by workstream. Keep this PR Draft and unmerged.


## Round 2 — independent evidence intake and preliminary cross-PR audit

**Updated:** 2026-11-10T23:37:42.555Z (UTC)  
**Task status:** In progress — the entry condition is now met; preliminary audit has started.  
**Audit branch:** `audit/assistant-13-independent-final-review`

### Evidence intake: assistants 1–12

Retrieved the current progress reports for assistants 01–12 from their feature branches. The reports are evidence leads, not accepted completion proofs. The authors' reported task percentages are:

| Assistant | Self-reported progress | Current report-level status |
|---|---:|---|
| 01 Angular | Audit 100%; implementation slice 50% | Audit report complete; separate implementation PR #32 open |
| 02 Backend | 54% | In progress |
| 03 Flutter | 10% | In progress |
| 04 R/Climatol | 55% | In progress |
| 05 Electronic auditor | 25% | In progress |
| 06 QA | 50% | In progress |
| 07 Security | 40% | In progress |
| 08 Database | 10% | In progress |
| 09 DevOps | 75% | In progress |
| 10 Requirements/docs | 65% | In progress |
| 11 Scientific review | 10% | In progress |
| 12 Integration | 83% | In progress |

These percentages are copied as author-reported figures only. They are not independent acceptance scores and do not indicate project completion.

### PR heads and changed-file inventory

Inspected GitHub PR metadata and changed-file lists for PRs #19–#30, and separately inspected new Angular implementation PR #32.

- PRs #19–#30 are open, Draft, and unmerged.
- PR #32 is open, Draft, unmerged, and targets `work/legacy-ui-migration-audit`.
- PR #19 also targets `work/legacy-ui-migration-audit`.
- PR #23 targets `work/climate-analytics-r-bootstrap`.
- The other reviewed PRs #20–#22 and #24–#30 target `main`.

The different base branches mean the PR set is not a single flat stack. The integration owner must preserve the intended parent branches and inspect ancestry before any merge/rebase decision.

### Confirmed cross-PR collision risk

The changed-file lists show several independent PRs adding the same shared paths:

- `واجهات/مهما.md`
- `واجهات/تغيير.md)
- `واجهات/README.md`

Fetched `واجهات/مهما.md` from eight assistant branches (#19, #21, #22, #25, #26, #28, #29, #30). All eight versions had different contents. This confirms competing versions of the same shared file path, not merely a theoretical overlap. Do not merge these branches blindly. Reconcile the shared records append-only under one controlled integration owner, preserving every assistant's entries. PR #20, #23, #24 and #27 do not add those same coordination paths in their inspected file lists.

### Current-head GitHub Actions evidence

Queried workflow runs by the exact current PR head SHA:

| PR | Assistant / area | Current-head workflow evidence |
|---|---|---|
| #19 | 01 UI specification | No run returned |
| #20 | 05 electronic auditor | No run returned |
| #21 | 03 Flutter | Client CI #42924658140 — pending |
| #22 | 02 Backend | Backend build #42924570653 — success |
| #23 | 04 R/Climatol | Climate Analytics R #42924712490 — success |
| #24 | 06 QA | No run returned |
| #25 | 11 scientific | No run returned |
| #26 | 08 database | No run returned |
| #27 | 09 DevOps | Client CI #42924596524 — success |
| #28 | 12 integration | No run returned |
| #29 | 10 requirements/docs | No run returned |
| #30 | 07 security | Backend build #42924701188 — success; Client CI #42924701234 — success |
| #32 | 01 Angular implementation | No run returned |

Run links:
- [PR #21 Client CI](https://github.com/gfa437926-tech/metra2027/actions/runs/42924658140)
- [PR #22 Backend build](https://github.com/gfa437926-tech/metra2027/actions/runs/42924570653)
- [PR #23 Climate Analytics R](https://github.com/gfa437926-tech/metra2027/actions/runs/42924712490)
- [PR #27 Client CI](https://github.com/gfa437926-tech/metra2027/actions/runs/42924596524)
- [PR #30 Backend build](https://github.com/gfa437926-tech/metra2027/actions/runs/42924701188)
- [PR #30 Client CI](https://github.com/gfa437926-tech/metra2027/actions/runs/42924701234)

“No run returned” is recorded as no verified workflow evidence for that exact head, not as a pass or failure. Historical runs cited inside assistant reports were not substituted for current-head evidence.

### Preliminary source-level review

Read the current branch versions of:
- `backend/Metra.Api/Features/Observations/ObservationSubmissionEndpoints.cs`
- `backend/Metra.Api.Tests/Features/Observations/ObservationSubmissionRequestGuardTests.cs`
- `mobile/metra_mobile/lib/core/api/metra_api_client.dart`
- `mobile/metra_mobile/lib/features/observations/observation_review_screen.dart`
- `backend/Metra.Api/Program.cs`
- `.github/workflows/climate-analytics-r.yml`

Preliminary findings requiring full audit tracking:

1. **SEC-AUD-001 — anonymous API rate-limit gap (candidate P1):** in the current security branch, the global limiter returns `GetNoLimiter("anonymous")` when there is no JWT subject. The separately configured `readiness` policy only protects the readiness endpoint. Therefore the code does not apply the stated conservative anonymous fallback limit to other unauthenticated routes. Confirm the effective middleware behavior and add a negative test before accepting this hardening.
2. **API/UTC — partial boundary enforcement:** the observation submission request guard rejects non-zero DateTimeOffset offsets and has a corresponding unit test. It does not call the hourly/daily/phenomenon domain validators in the inspected endpoint. UTC enforcement is therefore not proof of complete payload/domain validation.
3. **Flutter station DTO — compatibility risk:** the inspected Flutter parser requires `local_station_code` and `name_en` to be non-null strings. Assistant 12 reports that the API projection permits null for those fields. This remains a cross-file compatibility finding to confirm against the exact endpoint projection and fixtures.
4. **R workflow trigger coverage:** the workflow's push branch list contains `work/climate-analytics-r-bootstrap` only; pull-request and manual triggers exist. Pushes to `main` will not trigger this workflow under the current configuration. Confirm intended post-integration CI policy with DevOps and R owners.

No finding above is treated as release-closed. The anonymous limiter issue is a source-level discrepancy; no live penetration test was performed.

### Files examined in this round

- Assistant progress reports 01–12 on their respective feature branches.
- PR metadata and changed-file lists for #19–#30 and #32.
- Current-head Actions run records for #19–#30 and #32.
- The six source/workflow files listed in the preliminary source-level review.
- Eight branch versions of `واجهات/مهما.md` to verify shared-file divergence.

### Files changed by assistant 13

- `docs/progress/assistant-13.md` — appended this round.
- `docs/changelog/assistant-13.md` — appended this round.

No other assistant's report, shared coordination file, application source, database, migration, or original observation was modified.

### Tests and safety

- Tests run by assistant 13: none. This round was a GitHub evidence and static-source inspection.
- CI: the statuses above are queried GitHub Actions results, not tests run locally by assistant 13.
- No database or Supabase connection or modification.
- No migration, merge, rebase, deployment, or production access.
- PR #31 remains Draft and unmerged.

### M13 progress and remaining work

**Independent audit completion: 0% of 12 workstreams closed; 3 workstreams have been opened.** The strict completion numerator counts only fully verified and closed audit workstreams. PR inventory, branch collision discovery, and initial source/CI triage are in progress but do not yet satisfy full acceptance criteria.

**Remaining:** 12 audit workstreams remain open; 3 have preliminary evidence collected. No final readiness recommendation is possible.

**Next:** complete a patch-level review of the high-risk security, backend validation, Flutter DTO, R workflow and database contract changes; verify the disputed findings against endpoint projections, SQL/RPC and tests; then reconcile the shared-file collision and PR ancestry with the integration owner. Keep all PRs unmerged pending owner review.


## Round 3 — patch-level cross-stack verification and current-head CI inspection

**Updated:** 2026-11-11T09:29:41Z (UTC)  
**Task:** M13 — Independent final audit.  
**Status:** In progress; one current-head CI failure and two implementation/coverage gaps were confirmed at source/Actions level.  
**Branch:** `audit/assistant-13-independent-final-review`  
**PR:** [#31](https://github.com/gfa437926-tech/metra2027/pull/31), open / Draft / unmerged.

### Evidence checked in this round

| PR | Exact head SHA | Current-head Actions result | Independent observation |
|---|---|---|---|
| #21 Flutter | `5c55304719c9161849518f5285337a0fa4c5fbca` | [Client CI #42931168114](https://github.com/gfa437926-tech/metra2027/actions/runs/42931168114) — **failure** | Angular build passed; Flutter analyze failed; Flutter tests were skipped. |
| #22 Backend | `0d29163a4457c12f38e8a1c79b7dec49248c143d` | [Backend build #42925286446](https://github.com/gfa437926-tech/metra2027/actions/runs/42925286446) — **success** | All listed build, SQL-contract, API-test and container-build steps completed successfully. |
| #23 R/Climatol | `c139d03a9b3b321c92f33b736eccf95fbd45c5b9` | [Climate Analytics R #42931277732](https://github.com/gfa437926-tech/metra2027/actions/runs/42931277732) — **success** | Current PR head's R workflow completed successfully. |
| #30 Security | `b4ab7e5cb60690ccd06bb3d7b7f3690f46b30bb2` | [Backend #42925422751](https://github.com/gfa437926-tech/metra2027/actions/runs/42925422751) and [Client CI #42925422685](https://github.com/gfa437926-tech/metra2027/actions/runs/42925422685) — **both success** | Both current-head workflows passed; this does not itself close the security review. |
| #31 Independent audit | `3297f54c8ecd6366f85527b9b8440585e90a9419` | No PR-triggered run returned for this head | No CI result is claimed for the audit documentation PR. |

### Confirmed finding — Flutter analyzer blocks tests (M13-FLT-001)

The current #21 workflow log shows `flutter analyze` failed with eight analyzer issues in `mobile/metra_mobile/test/widget_test.dart`:
- Three invalid reads of `TextFormField.obscureText`.
- One unavailable `http.Response.json` method.
- Undefined `SemanticsFlag` and `SemanticsAction`.
- Unavailable `SemanticsNode.hasAction`.
- A deprecated `hasFlag` use is also reported as an informational issue.

Because the workflow stops after analyzer failure, `flutter test` was skipped. The added widget tests therefore have not been validated by this run. This is a confirmed CI blocker for PR #21, not merely missing evidence. The Angular build job in the same workflow passed.

### Backend UTC scope — partial validation remains (M13-API-001)

The #22 patch adds a guard rejecting non-zero `DateTimeOffset.Offset` values and a focused unit test. The changed endpoint guard still returns after structural payload checks and UTC offset validation; the patch does not demonstrate invocation of the hourly/daily/phenomenon domain validators. The current-head Backend workflow passed, but that pass must not be interpreted as proof of full meteorological payload validation. Keep the finding open pending an endpoint-to-domain-validator trace and tests for invalid domain values.

### Security rate-limit scope — coverage gap requiring owner decision (M13-SEC-001)

The #30 `Program.cs` configures the global limiter to return `GetNoLimiter("anonymous")` when no JWT subject is present. It adds a separate fixed-window `readiness` policy, and the new test verifies the readiness limit only. Thus the implementation does not impose a general anonymous global bucket. This is recorded as a coverage/design gap, not a proven exploit: the owner must confirm which anonymous routes are intentionally exposed and add a negative/positive test for unauthenticated requests to protected endpoints plus any public route requiring throttling. Do not infer that authenticated authorization is bypassed.

### R workflow trigger note (M13-R-001)

The current #23 workflow patch pins Climatol 4.5-0 and verifies the installed version; current-head R CI passed. The workflow's push trigger remains scoped to the climate bootstrap branch rather than `main`. This is acceptable for the present stacked-PR base only if a separate post-integration workflow policy is defined. Confirm main-branch CI coverage before integration; do not treat current PR success as proof that pushes to main will run the climate workflow.

### Shared-file and integration status

The previously confirmed divergence remains unresolved: multiple PR branches carry different versions of `واجهات/مهما.md`, and overlapping coordination paths occur in several PRs. PR #19/#32 and #23 also have non-main target branches. No merge, rebase, or shared-file rewrite was attempted.

### Files and safety

- **Files inspected:** exact PR patches for #21, #22, #23 and #30; current-head workflow records; PR #21 Flutter analyzer job log; changed-file lists; assistant-13 current progress/changelog.
- **Files changed in this round:** only this assistant-13 progress report and append-only changelog (documentation updates).
- **Tests run by assistant 13:** none. CI evidence above was retrieved from GitHub Actions.
- **Database/Supabase/migrations/raw observations:** not accessed or modified.
- **Merge/rebase/deployment/secrets:** none.

### Progress accounting

**M13 completion remains 0% of 12 workstreams formally closed.** This round materially advanced evidence collection and confirmed one CI blocker, but no full audit workstream meets its closure criteria yet. Three previously opened workstreams now have more precise findings; the remaining workstreams are still open.

**Remaining:** 12 audit workstreams remain open.  
**Next:** request/verify remediation of the Flutter analyzer errors, trace the Backend endpoint through its domain validators and tests, and obtain an explicit anonymous-route rate-limit decision. Then continue the full database-contract, immutable-record, scientific and release-evidence review. PR #31 remains Draft and unmerged.


## Round 4 — database/RPC and client-contract cross-check (read-only source audit)

**Updated:** 2026-11-11T09:48:14Z (UTC)  
**Task:** M13 — Independent final audit.  
**Status:** In progress; one critical database contract defect and two release-blocking baseline/integration gaps independently confirmed from Git source.  
**Branch:** `audit/assistant-13-independent-final-review`  
**PR:** [#31](https://github.com/gfa437926-tech/metra2027/pull/31), open / Draft / unmerged.

### Evidence examined

- PR #26, head `6e11eceb02b2d1567ffa5e436e1e6dd59028dbc8`, branch `work/database-engineering-audit`, base SHA `87f71356083843b2abdef76baf011a82510686be`; current-head PR workflow query returned no runs.
- PR #28, head `9b3ad187de7cbbf861dd7b091c193172e5a77ea9`; current-head PR workflow query returned no runs.
- Read-only source files on `main`: `supabase/migrations/20261103164003_create_operational_observation_submission.sql` (blob `9bbe23891aaecbedbea7537f7875ef7895442760`) and `supabase/migrations/20261103215400_observation_review_decision.sql` (blob `bc62268432c94d481e5e274625c5d59eea8ce528`).
- Read-only proposal on PR #26: `docs/database/proposed-migrations/20261111_01_fix_observation_audit_event_type.sql.proposal` (blob `8b66ba679f16436e61b72e86e3d1f1ea73d3630f`).
- PR #28 source-level cross-check: `docs/architecture/API-CONTRACT-CROSSCHECK.md` (blob `1e138fa5dcab2c8e5a53ddc861e31b14bde0f569`).
- PR #26 database audit and migration register, including DB-001 through DB-016 and the explicit warning that static shell grep contracts are not PostgreSQL integration tests.

### Confirmed critical finding — decision RPC event constraint mismatch (M13-DB-001)

The migration on `main` creates `metra_observation_audit_events.event_type` with an allow-list containing `returned` and `approved`. The separate `metra_decide_observation` RPC writes `p_decision` directly, whose allowed API values are `approve` and `return_for_correction`. These values violate the audit table check constraint. Because the insert occurs in the same function transaction after the observation status update, the audit insert is expected to fail and roll back the decision transaction for both approve and return-for-correction.

The assistant-08 proposal maps decisions to event values `approved` / `returned` and includes null decision validation. It is correctly stored under a `.proposal` path outside active migration folders. It is **not applied, not approved, and not tested**. This independent static confirmation elevates DB-001 to a release-blocking defect pending an isolated PostgreSQL regression test proving both decisions commit and append their audit events.

### Confirmed release blocker — missing baseline schema (M13-DB-002)

PR #26's static inventory reports 27 `database/migrations` files beginning at 003 and five `supabase/migrations` files, with baseline migrations 001/002 absent from the inspected `main` tree. This prevents a reliable clean-room reconstruction of the intended schema from the repository alone. It does **not** prove that tables are absent from any live database. The correct next action is to locate an owner-approved baseline/schema snapshot and reconcile its provenance; do not invent a replacement baseline.

### Confirmed integration gap — validation endpoints are not invoked by clients (M13-INT-001)

PR #28's source-level cross-check shows daily/hourly validation endpoints exist in ASP.NET Core, but the inspected Angular and Flutter flows do not call them. It also records that the submission endpoint path checked in source applies structural guards and forwards to the RPC; the current evidence does not establish that the domain validators are called from the authoritative persistence path. This is a bypassable-client-validation risk until server-side enforcement is proven. Required evidence: negative API/RPC tests for required fields, physical range limits, cross-field consistency, units and timestamp semantics for each observation type.

### Other schema and data-integrity risks carried forward

PR #26's source review additionally records:
- DB-011: migration 020 expects `permission_grants.authority_id` to be populated before setting NOT NULL, but its migration body does not perform the required backfill.
- DB-013: observation audit immutability trigger covers UPDATE/DELETE but not TRUNCATE, unlike the authority audit pattern.
- DB-014: idempotency uniqueness is scoped to station/user/key and does not define the business duplicate policy for station/type/observed_at with different keys.
- DB-015: some read-model RPC authorization relies on API-level actor scoping; internal SQL actor authorization needs verification.
These remain static findings from the database assistant's review; no live database state or PostgreSQL behavior was tested in this round.

### PR / CI and safety

- PR #26 and #28 remain open Drafts; no PR-triggered workflow runs were returned for their current heads.
- Assistant 13 ran no tests. No SQL was executed and no Supabase project was accessed.
- Migration source files were read from Git only. No active migration was edited, copied into an executable migration folder, or applied.
- No live schema, old database, station data, observation data, secrets, deployment or production service was accessed.
- Only this assistant-13 progress report and append-only changelog are updated in this round.

### Progress accounting

M13 remains **0% of 12 audit workstreams formally closed**. DB-001, DB-002 and INT-001 are now backed by direct source-level evidence, but their closure requires owner-approved baseline recovery and PostgreSQL/API regression tests; discovery alone does not satisfy closure criteria.

**Remaining:** 12 audit workstreams remain open.  
**Next:** obtain a trusted baseline schema from the project owner; ask database owner to prepare and test the DB-001 correction in an isolated disposable PostgreSQL environment; require backend/client owners to add server-side domain-validation evidence and negative tests. Do not apply any changes to the new or old Supabase project. PR #31 remains Draft and unmerged.


## Round 5 — deeper DB-test and migration dependency review (2026-11-11T09:51:01.457Z UTC)

### Evidence rechecked
- Read the exact PR #26 branch sources: DATABASE-ENGINEERING-AUDIT.md, MIGRATION-REVIEW-REGISTER.md, and the review-only audit-event proposal. PR #26 head remains 6e11eceb02b2d1567ffa5e436e1e6dd59028dbc8; PR #28 head remains 9b3ad187de7cbbf861dd7b091c193172e5a77ea9.
- Re-read the active main observation creation and review-decision migrations (blobs 9bbe23891aaecbedbea7537f7875ef7895442760 and bc62268432c94d481e5e274625c5d59eea8ce528). The event-type mismatch is present in the exact source.
- Read the proposed correction blob 8b66ba679f16436e61b72e86e3d1f1ea73d3630f. It maps decisions to approved/returned and adds an explicit NULL decision check. It remains a non-executable .proposal outside migration directories; it is not approved, tested or applied.
- Inspected the repository's current database/tests inventory and three shell contract tests. These use static grep assertions against SQL/API text; they are not PostgreSQL integration tests and do not execute migrations or RPC transactions. No test file currently listed in that directory exercises metra_decide_observation with both decision branches.
- Re-read migration 020 (blob f82cca1d793b7806b27522900be834018ec285ac). It adds nullable authority_id, immediately aborts if any row remains NULL, then applies NOT NULL/FK; it contains no backfill. This confirms a migration precondition requiring an owner-approved data mapping or a proven empty/new-table precondition. No live database state was checked.
- Migration 020's authority-access audit trigger explicitly includes TRUNCATE. This does not remediate the separate observation-audit trigger gap recorded as DB-013.
- Re-read PR #28 API cross-check (blob 1e138fa5dcab2c8e5a53ddc861e31b14bde0f569): no client invocation of daily/hourly validation endpoints was found in inspected flows; persistence-path domain validation remains unproven. Static only.

### CI and tests
- Requeried PR-triggered workflow runs for PR #26 head 6e11eceb02b2d1567ffa5e436e1e6dd59028dbc8 and PR #28 head 9b3ad187de7cbbf861dd7b091c193172e5a77ea9: both returned zero runs. No CI success is claimed.
- Assistant 13 ran no tests. No SQL, PostgreSQL, API, build or device tests were executed.

### Findings and required proof
- M13-DB-001 remains release-blocking until isolated PostgreSQL tests prove approve and return_for_correction both commit the intended status and audit event, while unauthorized/null/invalid/stale-state cases leave both tables unchanged.
- M13-DB-002 remains open: obtain an owner-approved baseline/schema snapshot; do not reconstruct missing 001/002 migrations by guesswork.
- M13-DB-011 remains a migration-order/data-precondition blocker until a documented safe backfill or verified empty-table prerequisite is supplied and tested on disposable data.
- M13-INT-001 remains open until server-side domain validation is proven in the authoritative write path and negative tests cover requiredness, physical ranges, cross-field consistency, units and time semantics for every observation type.
- DB-013 observation-audit TRUNCATE protection and DB-015 SQL-side actor authorization still require direct source/isolated database verification; authority audit trigger coverage in migration 020 is not evidence for the observation audit table.

### Safety and scope
- Read-only GitHub source and Actions metadata inspection only. No live Supabase/database access; no SQL/migration execution; no DB/schema/data/secrets/source changes; no merge, rebase or deployment.
- Only assistant-13 progress and changelog documents are updated in this round.

### Progress accounting
- M13 remains 0% of 12 audit workstreams formally closed. Evidence depth increased, but no workstream meets its closure criteria because required executable regression tests, baseline approval, or owner acceptance are still absent.
- Remaining: 12 audit workstreams open. PR #31 remains open, Draft and unmerged.

## Round 6 — RPC authorization and audit immutability review (2026-11-11T09:54:11.928Z UTC)

### RPC authorization — positive controls confirmed by source
- Effective station permission predicate in database/migrations/020_authority_membership_and_permission_grant_lifecycle.sql checks active account, approved/active/non-demo station, active authority and country, approved current authority membership, approved current station assignment, active role-to-permission mapping, and approved non-revoked current permission grant. Function is SECURITY DEFINER with fixed search_path; execute is revoked from PUBLIC/anon/authenticated and granted to service_role.
- Effective authority permission predicate in migration 020 similarly scopes the grant to p_authority_id and requires active account/authority/country, approved current membership, active role mapping and approved current grant. Execute is service_role-only.
- metra_decide_observation rechecks the specific decision permission inside the RPC and locks the observation row FOR UPDATE before checking submitted state and updating it. The .NET decision endpoint derives actor user ID from the verified JWT sub, validates the decision, checks the corresponding station permission, then invokes the service-role RPC. The RPC repeats station permission checking, which is useful defense in depth against endpoint-level TOCTOU.
- The decision RPC and permission RPCs are not executable by anon/authenticated/metra_api_runtime per their explicit grants. Service-role credentials are held in server configuration in the inspected .NET service.

### RPC authorization — residual trust boundary / gaps
- metra_decide_observation accepts p_user_id as a parameter and does not independently bind it to auth.uid()/a user JWT subject. That is consistent with the current service_role-only RPC architecture, but it makes the API's verified-subject derivation and protection of the service-role secret a critical trust boundary. Required proof: endpoint integration tests show body/route cannot override actor identity; a service-role credential compromise is outside this RPC's end-user identity control.
- get_station_audit_log is a SECURITY DEFINER read RPC granted only to service_role and has no SQL-side actor/station authorization predicate. The current API endpoint is expected to enforce station permission before invoking it. Treat this as a trusted-server boundary; require negative API tests for cross-station reads and keep the RPC unavailable to browser roles.
- Source-only review cannot prove deployed grants, function owners, role attributes (BYPASSRLS), actual policies, or effective privileges in the target database.

### Audit immutability — exact findings
- Operational observation audit table: migration 20261103164003 enables and forces RLS, revokes all from PUBLIC/anon/authenticated/metra_api_runtime, grants service_role SELECT/INSERT only, and installs BEFORE UPDATE OR DELETE row trigger that raises. A separate migration adds deny policies for anon/authenticated. This blocks ordinary UPDATE/DELETE through the granted application role, but the trigger does not cover TRUNCATE. No explicit TRUNCATE privilege is granted to service_role in the inspected migration, so this is a defense-in-depth/privilege-drift gap rather than proof that the current service_role can truncate. Require explicit TRUNCATE trigger coverage and ACL regression tests.
- Authority access audit table: migration 020 enables+forces RLS, denies browser roles, grants service_role SELECT, and installs BEFORE UPDATE OR DELETE OR TRUNCATE statement trigger. Migration 024 further revokes INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER from service_role, leaving SELECT; SECURITY DEFINER lifecycle RPCs own the intended writes. Static shell contract verifies some SQL fragments, not effective runtime privileges.
- Station audit log: migration 014 defines a service_role-only SECURITY DEFINER read projection, but the migration/test inventory inspected does not establish the source table's append-only trigger or its UPDATE/DELETE/TRUNCATE protections. Its contract test checks read projection and permission requirement only. Immutability remains unproven; request the authoritative table-creation migration and ACL/trigger tests.
- Observation audit immutability is not complete against TRUNCATE at trigger level. Authority audit trigger includes TRUNCATE; do not conflate the two tables.

### Backend / Database owner evidence review
- Backend PR #22 head 0d29163a4457c12f38e8a1c79b7dec49248c143d: workflow 42925286446 succeeded. Logs show 239/239 .NET tests passed and static SQL contract steps passed. Changed test inventory includes decision request-guard tests and authentication/queue tests, but no ObservationDecisionEndpoint integration test; the existing decision guard tests validate shape/notes only. No RPC/DB transaction tests.
- Security PR #30 head b4ab7e5cb60690ccd06bb3d7b7f3690f46b30bb2: workflow 42925422751 succeeded with 236/236 .NET tests; Client CI 42925422685 succeeded with Flutter analyze/test (13 tests) and Angular build. These runs do not prove DB authorization or audit trigger behavior.
- PR #26 Database head 6e11eceb02b2d1567ffa5e436e1e6dd59028dbc8 and PR #28 Integration head 9b3ad187de7cbbf861dd7b091c193172e5a77ea9: exact-head PR workflow query returned zero runs for both. No CI result claimed.
- PR #26 proposal still is not an active migration and does not contain runtime test evidence. Latest main migration 20261103220500 hardens NULL decision validation but still inserts p_decision ('approve'/'return_for_correction') directly into event_type, so the event-type CHECK mismatch remains unresolved in active source.

### Required evidence before closure
- Backend owner: add API integration tests for authenticated approve and return, each required permission, wrong-station/wrong-permission 403 with no RPC call, unauthenticated 401, malformed/null/invalid request handling, and identity sourced only from validated JWT sub. Include test proving RPC call arguments cannot be supplied/overridden by request body. Supply successful workflow link and test count.
- Database owner: add disposable PostgreSQL integration tests (not grep-only) applying the relevant migrations and invoking both decision branches; assert status+audit event commit together, and unauthorized/null/invalid/not-found/stale-state paths change neither table. Include privilege matrix for anon/authenticated/metra_api_runtime/service_role and attempts to UPDATE/DELETE/TRUNCATE observation and authority audit rows.
- Database owner: add TRUNCATE immutability trigger/contract for metra_observation_audit_events, and provide authoritative source migration plus mutation tests for station_audit_log. Verify effective ACLs and trigger behavior in disposable CI DB, never against either live project without owner approval.
- Database owner: verify SECURITY DEFINER owner/search_path/EXECUTE ACLs and SQL-side scope checks; specifically test cross-station and cross-authority IDs against permission RPCs and station audit reads.
- Integration owner: provide negative API tests proving client bypass cannot persist invalid daily/hourly/phenomenon payloads.

### Safety / status
- GitHub source and Actions logs only. No live DB/Supabase access, SQL execution, migration changes, data changes, secrets changes, merge, rebase or deployment. No owner branch/source files modified.
- M13 progress remains 0% of 12 audit workstreams formally closed; all 12 remain open because the requested runtime/negative tests and owner evidence are not yet present.

## Round 7 — fresh owner-branch, SQL projection and endpoint evidence check

**Updated:** 2026-11-11T10:51:21.524Z (UTC)  
**Task/status:** M13 independent final audit; in progress.  
**Branch:** audit/assistant-13-independent-final-review; PR [#31](https://github.com/gfa437926-tech/metra2027/pull/31), open Draft and unmerged.

### Fresh PR/head/Actions check

- PR #22 Backend remains open Draft, branch work/backend-api-audit-assistant-2, exact head 0d29163a4457c12f38e8a1c79b7dec49248c143d. Its current-head Backend build [#42925286446](https://github.com/gfa437926-tech/metra2027/actions/runs/42925286446) remains successful. No newer head or run was returned.
- PR #26 Database remains open Draft, exact head 6e11eceb02b2d1567ffa5e436e1e6dd59028dbc8; exact-head PR workflow query returned no runs.
- PR #28 Integration remains open Draft, exact head 9b3ad187de7cbbf861dd7b091c193172e5a77ea9; exact-head PR workflow query returned no runs.
- PR #31 audit branch head before this report update was 94fd7546ee487bf3b953519a297834659619fbf2; no PR-triggered workflow run was returned for that head.
- Changed-file inventories for #22/#26/#28 are unchanged from the previous review. #26 still contains only a review-only SQL proposal, not an active migration. #28 still contains architecture/contract documentation and no executable integration tests.

### Backend review-queue vs decision coverage

- Read PR #22's changed test patch. It adds HTTP integration tests for the review queue (401 unauthenticated, 400 invalid limit, 403 station denial, and no queue call on denial) plus a focused UTC request-guard unit test. These are useful additions but do not test the observation decision endpoint.
- Current backend/Metra.Api.Tests/Features/Observations inventory contains ObservationDecisionRequestGuardTests.cs, but no ObservationDecisionEndpointTests.cs or equivalent decision endpoint integration fixture. No test proves authenticated approve/return calls the RPC, wrong-station/wrong-permission denial prevents the RPC, or actor identity cannot be overridden by the body.
- The #22 head CI success remains valid evidence for that commit only; prior run log recorded 239/239 .NET tests. It does not close decision/RPC transaction coverage.

### Station audit log — source and authorization boundary

- Read database/migrations/014_station_audit_read_model.sql (blob 7d317f60bb6973bfcd9de9182716b435b3b03ea7). It creates/replaces get_station_audit_log(p_station_id,p_limit) as SECURITY DEFINER with fixed search_path = pg_catalog, public, bounds limit to 1–250, filters records by the requested station and station assignments, revokes execute from PUBLIC/anon/authenticated and grants it to service_role.
- Read backend/Metra.Api/Features/Users/StationAuditEndpoints.cs (blob 4e3fcffe9746d1b152188c9ea1bb133b0fd6d27d). The API endpoint applies .RequireStationPermission(users.station.view) before invoking the service-role RPC. The RPC does not receive actor ID or independently evaluate actor permission; this is an API-to-service-role trust boundary. Require negative cross-station API tests and ensure service-role credentials remain server-only.
- Read database/tests/verify_station_audit_contract.sh (blob 3500a62fc4eb5b9b0bfdff7e7b929853e4cda6d9). It is a static grep contract test for RPC name/filter/limit/EXECUTE grants and API permission mapping, not a PostgreSQL runtime or mutation test.
- Repository migration inventory has no checked-in creation/baseline migration for the underlying station_audit_log table in the inspected database/migrations sequence (003–029); migration 014 is a read projection only. Therefore source-table RLS, grants, trigger, UPDATE/DELETE/TRUNCATE protection and ownership cannot be verified from this repository baseline. Do not infer the live table's protection or absence.

### Reconfirmed active database defect and test gap

- Main migration supabase/migrations/20261103220500_harden_observation_decision_null_validation.sql (blob e3115f6f9830930ab38879e3ed55cdbc25678e21) still inserts p_decision directly into event_type; the creation migration CHECK permits approved/returned, not approve/return_for_correction. The mismatch remains active in source; the PR #26 proposal is not an applied migration and has no runtime proof.
- database/tests contains shell contract checks; the station audit check and previously inspected decision/permission checks use static source assertions. No disposable PostgreSQL integration test applying migrations and exercising both decision branches was found in the reviewed inventory.
- Observation audit trigger still covers UPDATE/DELETE, not TRUNCATE. No explicit TRUNCATE grant to service_role was found in the inspected creation migration; retain this as defense-in-depth/privilege-drift gap, not proof of current exploitability.

### Tests, changes and safety

- Tests executed by assistant 13: none. GitHub Actions evidence is the exact-head status above; no new workflow result was available for #26/#28.
- Files modified this round: only docs/progress/assistant-13.md and append-only docs/changelog/assistant-13.md on the assistant-13 branch, plus PR #31 description.
- No live Supabase/database access, SQL execution, migration/schema/data/secrets change, owner-branch modification, merge, rebase or deployment.

### Progress and remaining work

**M13 completion remains 0% of 12 substantive audit workstreams formally closed; 12 remain open.** This round advances source/coverage verification but no workstream satisfies the defined closure criteria (owner evidence plus executable negative/runtime tests and accepted traceability). Assistant-specific progress percentages in other PRs are not project completion.

**Next:** require the Database owner to provide an authoritative station_audit_log source/baseline definition and disposable PostgreSQL ACL/immutability tests; require Backend owner to add decision endpoint integration tests; require Database owner to add both decision-branch transaction tests and correct the event vocabulary through an owner-reviewed migration. Keep all PRs Draft/unmerged until acceptance.
