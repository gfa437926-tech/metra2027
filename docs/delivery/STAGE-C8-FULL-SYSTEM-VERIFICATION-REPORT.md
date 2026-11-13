# Stage C8 — Full-System Verification

**Branch:** `work/backend-db-integration-phase`  
**Verified HEAD:** `fe62488e5d95c1a442ab3c17f7884d92cb47f794` (docs commit) + prior code through `d89eef1…`  
**Re-run date:** 2026-11-12 (this session)

## Backend (.NET) — fresh run
| Suite | Result |
|-------|--------|
| `dotnet build` Metra.Api Release | **Success** |
| Full Metra.Api.Tests | **Passed 264 / Failed 0 / Skipped 0** |

## Database (isolated PostgreSQL) — fresh run
| Check | Result |
|-------|--------|
| Path N `metra_c8v` | exit **0** |
| Grant uniqueness (`05_…`) | **ALL GRANT UNIQUENESS TESTS PASSED** |
| R4 apply/rollback/reapply | **OK** |
| Archive isolation `metra_c8a` (`00`→`01`→`02`) | **ALL ARCHIVE ISOLATION TESTS PASSED** |
| Path H hosted | **Not executed** |

## Flutter
See `STAGE-C8-FLUTTER-TEST-CLOSURE-REPORT.md`. Suite **not executed** (1.2 GiB RAM, no swap, Flutter tool OOM history).

## E2E (login + Flutter UI + live API)
**Not executed** — identity provider + Flutter runtime not available in this sandbox.

## Regression
.NET 264 matches C4/C5/C8 prior count. Isolated DB suites green.
