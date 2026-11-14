# Stage C8.1 — Git History Reconciliation

**Date:** 2026-11-13  
**Local branch:** `work/backend-db-integration-phase`  
**Local HEAD:** `6e1f4205e4f67e02cb73fac7296740c939de4bf8`  
**Remote branch tip:** `c6d9a9f7dc332afdd54ca0ee859fa712f4153d12`  
**Remote base lineage:** `main` (`6ff6f36…`) + 3 CI/test commits  

## Divergence summary

| Axis | Local | Remote (`origin/work/backend-db-integration-phase`) |
|------|-------|------------------------------------------------------|
| Commit count (approx) | **75** from this line | **main + 3** (workflow + analyze flag + widget_test fix) |
| Backend .NET (C2–C6) | Present (rate limit, 409 grant conflict, authz tests, security headers) | **Absent** — still `main`-era API |
| `database/baseline`, Path N, proposals R4/grants | Present | **Absent** |
| C2–C9 delivery docs under `docs/delivery/` | Present (local series) | **Absent** (only main docs) |
| Flutter `widget_test` C7 fixes | Present | **Present** (`c6d9a9f`) |
| `flutter-c7-ci.yml` | Present | **Present** |
| Shared ancestor | N/A (histories diverged: local never fully pushed) | `6ff6f36` (main) |

## What is on GitHub (remote branch)

1. Full `main` content as of 2026-11-11 Flutter roadmap tip.
2. `.github/workflows/flutter-c7-ci.yml` (Flutter-only CI).
3. `flutter analyze --no-fatal-infos` adjustment.
4. Fixed `mobile/metra_mobile/test/widget_test.dart` (Navigator.pop + CheckboxListTile).
5. **C7 Actions run 43337342656: success, 16 tests passed.**

## What is local-only (must not be discarded)

- Backend Features: Observations, Stations, Users; RateLimiting; Security.
- `AuthorityAccessConflictDetector` / HTTP 409 for PostgreSQL 23505.
- Archive endpoint fail-closed (503).
- Domain/API authorization regression tests (264 tests in local tree).
- `database/baseline/**`, `database/isolated/**`, `database/proposals/**`.
- Delivery reports STAGE-C2.* through STAGE-C9.*.

## Conflicts

No file-level merge conflict was executed. Histories are **disjoint tips** sharing only distant main ancestry for the remote branch creation. Automatic merge would require a deliberate, reviewed integration (not performed in C8.1).

## Recommended transfer plan (needs explicit approval before any push)

1. Keep remote C7 workflow + widget_test fixes.
2. Push local backend/database/docs commits onto the same branch name **without force**, or merge local into a new tip after fetch.
3. Prefer sequential non-force push of local commits if remote only has the three CI commits on top of main — may need merge commit resolving workflow file twice.
4. **Do not force-push.** Do not delete branches.

## Decision

**Source of truth for Backend/DB:** local HEAD `6e1f420…`  
**Source of truth for C7 Flutter CI green evidence:** remote `c6d9a9f…` + Actions run `43337342656`  
**C8.1 status:** Reconciliation **documented**; full history transfer **pending user approval**.
