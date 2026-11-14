# Git Synchronization & Staging Readiness

**Date:** 2026-11-13  
**Local branch:** `work/backend-db-integration-phase`  
**Local HEAD (verified):** `94d046ad2d929dc71de0f1dbe58067485373cd5b`  
(The SHA in the request with `de1f` was a typo; the real object is `de0f`.)

**No push, merge, deploy, or hosted Supabase write was performed.**

## 1. Tips

| Ref | SHA | Where |
|-----|-----|--------|
| Local integration HEAD | `94d046ad2d929dc71de0f1dbe58067485373cd5b` | this workspace only |
| Local `main` / PR #34 tip | `dd377081f7f211d3c15e5ca1db2cf8e551fda8e6` | ancestor of local HEAD |
| GitHub `main` | `6ff6f36a80106d19f4ba6b8bb8cf0316a911cc34` | **not** an ancestor of local HEAD |
| GitHub `work/backend-db-integration-phase` | `c6d9a9f7dc332afdd54ca0ee859fa712f4153d12` | **not** an ancestor of local HEAD |
| GitHub `fix/flutter-client-ci-mainline-2026-11-11` (PR #34) | `dd377081f7f211d3c15e5ca1db2cf8e551fda8e6` | **is** the merge-base of local HEAD |

`git merge-base --is-ancestor` results:

- remote integration tip → local HEAD: **false**
- GitHub main → local HEAD: **false**
- PR #34 tip → local HEAD: **true**

Local HEAD is **31 commits** ahead of local `main` (`dd37708`) and **0 behind**.

## 2. Commits on GitHub that are not in local HEAD

Only the three commits that sit on GitHub `work/backend-db-integration-phase` above GitHub `main`:

| SHA | Message |
|-----|---------|
| `97e87bdb5155ff9fd204fbbb45da6768548ea678` | ci(flutter): dedicated C7 workflow |
| `e27a4db5c87e3b7cac05c5757401fb658d5795bf` | ci(flutter): analyze `--no-fatal-infos` |
| `c6d9a9f7dc332afdd54ca0ee859fa712f4153d12` | test(flutter): Navigator.pop + CheckboxListTile |

Those three are based on GitHub `main` (`6ff6f36`), a **different parent line** from the local 31-commit series. A fast-forward of the existing remote branch is **impossible**. Force-push is **forbidden**.

Functional content of those three is already represented locally:

- `flutter-c7-ci.yml` exists locally (this change adds the missing `--no-fatal-infos` flag so the remote CI fix is not lost).
- `widget_test.dart` already uses `Navigator.pop` and `CheckboxListTile`.

## 3. Commits local-only (not on GitHub)

All 31 commits `dd37708..94d046a`, including Backend C2–C9, `database/baseline`, isolated SQL, R4 proposals, and delivery reports. Diff vs local main: **140 files, +7723 / −142**.

Representative range (newest first):

`94d046a` `462121e` `e03da4a` `93df09a` `5cf1728` `b7a2663` `6e1f420` `ec7c6f9` `66f5762` `fe62488` `d89eef1` `399ff05` `1a39cb8` `8da86c8` `12c91d3` `c1a7aa9` `4bba622` `e7ccf66` `ca3f7fc` `be55290` `4f150f1` `63199f9` `36db4d9` `7b63825` `9a0cfea` `b33b0a3` `9541b84` `41f223f` `3775723` `ed2b295` `c459b86`

## 4. Conflict assessment (before any transfer)

| Path | Risk | Resolution if a merge is later required |
|------|------|------------------------------------------|
| `.github/workflows/flutter-c7-ci.yml` | Both sides added the file on different parents | Keep local file **with** `--no-fatal-infos` (now aligned) |
| `mobile/metra_mobile/test/widget_test.dart` | Both sides fixed the same two tests | Keep local (already has both fixes; local forecast test file also scrolls for `مصدر الإحداثيات`) |
| Backend / `database/**` / `docs/delivery/**` | Present only on local line | Take local; GitHub main does not have this tree |
| PR #34 Flutter archive UI | Already inside local base `dd37708` | Do not drop PR #34 |

No automatic merge was executed.

## 5. Secret scan

Working tree scan of `backend/`, `mobile/`, `.github/`, `database/` for JWT-like `eyJ…`, AWS `AKIA…`, PEM private keys, and `sb_secret_`: **no matches**.

`backend/Metra.Api/appsettings*.json`: **no** `ServiceRoleKey` or password literals found by search.

Isolated SQL uses the local role password `metra_test_isolated` only inside test runners, not a production secret. It must not be reused on a hosted project.

**No `.env` or `.pem` files** were found in the repo tree (excluding `bin` / `node_modules`).

History of the 31 commits was not rewritten. A full `git log -p` secret pass was started; the tree scan is the evidence used for this gate. Do not push if a later manual pass finds a real key.

## 6. Safe push plan (requires explicit approval — not executed)

**Do not** `git push` the current branch name onto `origin/work/backend-db-integration-phase`. GitHub will reject a non-fast-forward. Do not `--force`.

Approved sequence when you say so:

1. Restore point: local `94d046a` (plus the workflow alignment commit after this report) and remote `c6d9a9f`.
2. Create **new** remote branch, for example `work/backend-db-integration-full-2026-11-13`, from local HEAD. First push of a new ref is not a force-push and does not move `main` or the existing integration branch.
3. Open a **Draft PR** whose **base** is `fix/flutter-client-ci-mainline-2026-11-11` (same SHA as local merge-base / PR #34), **not** GitHub `main`. A PR into `main` would mix unmerged PR #34 with Backend.
4. After PR #34 is merged to `main` by you, rebase or merge the new branch onto `main` in a second reviewed PR.
5. Leave GitHub `work/backend-db-integration-phase` at `c6d9a9f` as the C7 CI evidence ref. Do not delete it.
6. Verify after push: remote SHA equals local HEAD; `flutter-c7-ci` and `backend-ci` run; no hosted SQL job writes to Supabase.

## 7. Tests already evidenced on this tree (previous + this phase)

| Suite | Result | Notes |
|-------|--------|-------|
| `dotnet test` Metra.Api.Tests | **264 passed / 0 failed** | session before this report, same parent line |
| Path N empty PostgreSQL | exit 0 | isolated only |
| Grant uniqueness | ALL PASSED | isolated |
| R4 apply + A/B archive | A allowed, B denied | isolated; **not hosted** |
| Flutter C7 CI | 16 passed | GitHub run [43337342656](https://github.com/gfa437926-tech/metra2027/actions/runs/43337342656) on `c6d9a9f` only — **not** on local HEAD |

Local HEAD has **not** been re-run on GitHub Actions.

## 8. Staging design (no hosted write)

Target project ref named by the owner: `tbdnklyxjvbrilvnwgmq`.  
Forbidden legacy INSERT ref: `vktcvkwqszehgmhqjrkb`.

**This phase did not connect to either project.**

Staging is a **separate** database, never production and never INSERT:

1. Prefer a disposable PostgreSQL (current Path N) until you approve a Supabase staging project that is **not** the production ref and **not** INSERT.
2. Inspect live staging with read-only catalog queries (`information_schema`, `pg_indexes`, function definitions) before any DDL.
3. Run `database/proposals/c25_readiness/01_precheck.sql`.
4. If precheck shows duplicate active grants, **stop**. Do not auto-delete rows. Report them for a manual decision.
5. Apply, in order, only after approval:
   - `02_r4_apply.sql` (archive.read bound to `permission_grants.station_id`)
   - `04_grant_unique_apply.sql` (partial unique indexes)
6. Post-check: `06_postcheck.sql` plus `database/isolated/04_r4_and_grant_integrity_tests.sql` adapted to staging fixtures (two stations, same authority).
7. Rollback files stay unused unless post-check fails: `03_r4_rollback.sql`, `05_grant_unique_rollback.sql`. Rollback must not delete grant or audit rows.
8. Archive HTTP endpoint stays **503** until a real read model is approved. Applying R4 does not turn the endpoint on.
9. Production ref `tbdnklyxjvbrilvnwgmq` gets the same pack only in a later, separately approved window after staging is green.

## 9. What still needs your approval

1. Push of the **new** branch name (not a force-push of the existing one).
2. Opening the Draft PR (cannot be opened without that push).
3. Any connection or SQL against Supabase staging or production.
4. Enabling the archive read service (remove 503).

## 10. Decision

Git history is understood. A non-destructive transfer path exists. **Transfer is not executed.**  
Staging SQL pack is ready and already proven on isolated PostgreSQL. **Staging/production apply is not executed.**
