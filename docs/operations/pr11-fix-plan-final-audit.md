# Final audit — METRA fix plan (updated)

**Branch:** `work/legacy-ui-migration-audit`  
**Previous tip with green CI:** `df02b37f2bbc53c407f1d67b947e9131ae33e509`  
**This document tracks the follow-up risk-closure commits after that tip.**  
**PR #11:** Draft — **not merged**  
**Databases:** no apply, no legacy touch

## Proven (automated)

| Area | Proof |
|---|---|
| Flutter analyze / observation tests | Client CI green on df02b37 lineage |
| Backend build + permission unit/integration tests | Backend CI green on df02b37 lineage |
| Transition permission split update vs resolve | Unit + API integration tests |
| Cross-station API deny (list/detail/transition) | Equipment + support authorization tests |
| Detail payload station mismatch | Fail-closed 404 tests (this change set) |

## Not proven (explicit)

| Risk | Why unproven |
|---|---|
| PostgreSQL RLS / `SET LOCAL` live | Requires disposable DB + approved migration apply |
| Attachments / export isolation | **No routes implemented** |
| `operations.analytics.read` | Documented only, not wired |
| Hosted Supabase schema drift | Not introspected from this environment |
| `legacy_users_staging` origin | Owner decision |

## Documents
- `docs/security/SUPPORT-MAINTENANCE-AUTHORIZATION-MATRIX.md` — matched to code/tests
- `docs/security/service-role-support-maintenance-review.md`
- `docs/security/postgres-isolation-test-plan.md`
- `database/tests/ops_station_isolation_pg_test.sql` — placeholder for approved disposable run

## Confirmation
No PR merge. No SQL applied to any hosted database. No legacy database contact.
