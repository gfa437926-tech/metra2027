# Stage C8 — Full-System Verification

**Branch:** `work/backend-db-integration-phase`  
**Base HEAD:** `d89eef1b666918900ebdd6dcc497fa776edf4008`

## Backend (.NET) — re-run on current code
| Suite | Result |
|-------|--------|
| `dotnet build` Metra.Api Release | **Success** |
| Full Metra.Api.Tests | **Passed 264 / Failed 0 / Skipped 0** |

## Database (isolated PostgreSQL)
| Check | Result |
|-------|--------|
| Path N `metra_c8` | exit **0** |
| Grant uniqueness concurrency | **ALL … PASSED** |
| R4 apply/rollback/reapply | **OK** |
| Archive isolation suite `metra_c8_arch` | **ALL ARCHIVE ISOLATION TESTS PASSED** (A allow, B deny, role-only deny, revoke, expired assignment, audit append-only) |
| Path H hosted | **Not executed** (forbidden) |

## Flutter
See `STAGE-C8-FLUTTER-TEST-CLOSURE-REPORT.md` — suite **not run** in this environment.

## E2E local (Backend + real login + Flutter UI)
**Not executed** — no full identity provider stack + Flutter runtime in this 1.2 GiB sandbox.

## Regression vs C2.4–C7
.NET count matches C4/C5 baseline (264). No failure introduced on backend/DB isolated path.
