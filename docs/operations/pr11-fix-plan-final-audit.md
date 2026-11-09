# Final audit — METRA fix plan (updated)

**Branch:** `work/legacy-ui-migration-audit`  
**Previous tip with green CI:** `df02b37f2bbc53c407f1d67b947e9131ae33e509`  
**Latest audited code change:** `10bfc3314d9be10d345a6ad9e7b54157e5527060`  
**PR #11:** Draft — **not merged**  
**Databases:** no hosted apply, no legacy access

## Proven (automated)

| Area | Proof |
|---|---|
| Flutter analyze / observation tests | Client CI green on df02b37 lineage |
| Backend build + permission unit/integration tests | Backend CI green on df02b37 lineage |
| Transition permission split update vs resolve | Unit + API integration tests |
| Cross-station API deny (list/detail/transition) | Equipment + support authorization tests |
| Detail payload station mismatch | Fail-closed 404 tests (10bfc331) |

## Not yet proven

| Risk | Why unproven |
|---|---|
| PostgreSQL RLS / `SET LOCAL` live | A disposable-Postgres SQL harness now exists, but it has not been executed in CI or staging |
| Hosted Supabase schema drift | Not introspected in this review; no hosted connection used |
| Attachments / export isolation | **No API routes implemented** |
| `operations.analytics.read` | Documented only, not wired |
| `legacy_users_staging` origin | Owner decision |

## Disposable PostgreSQL harness

- `database/tests/ops_station_isolation_pg_test.sql` is an executable psql harness, not a placeholder.
- It refuses any database other than `metra_ops_test`, requires the target operational tables to be empty, checks RLS and FORCE RLS, includes station isolation and assignee authorization scenarios, and rolls fixtures back.
- It includes `database/tests/equipment_fault_npgsql_isolation.sql` and `database/tests/ops_assignee_authorization_pg_test.sql`.
- `database/tests/ops_role_grant_boundary_pg_test.sql` separately checks role flags, grants, client denials, RPC execute privileges and audit boundaries.
- Remaining gap: these scripts are not currently wired into an automated disposable-Postgres CI job, and no live run is claimed.

## Documents

- `docs/security/SUPPORT-MAINTENANCE-AUTHORIZATION-MATRIX.md` — aligned with API code/tests
- `docs/security/service-role-support-maintenance-review.md`
- `docs/security/postgres-isolation-test-plan.md`

## Confirmation

No PR merge. No SQL applied to any hosted database. No connection to the legacy database.
