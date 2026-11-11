# Final audit — METRA fix plan (CI evidence refreshed)

**Branch:** `work/legacy-ui-migration-audit`  
**PR #11:** Draft — **not merged**  
**Client CI run:** `42701716482` — success  
**Backend build run:** `42701716535` — success  
**Databases:** no hosted apply, no legacy access

## Proven on the audited branch

| Area | Evidence |
|---|---|
| Flutter | `flutter pub get`, `flutter analyze`, and `flutter test` all passed in Client CI run `42701716482` |
| Angular | `npm test` and production `npm run build` passed in the same Client CI run |
| Real Chromium PWA / IndexedDB E2E | Three independent Playwright runs passed; each reported service worker, offline save/reopen, automatic sync, server rejection blocking, transient retry, hourly queue recovery, and daily/hourly concurrency checks as true; `maxConcurrentPosts=1`; `runtimeErrors=0` |
| .NET | API build, domain/API tests, production container build, and liveness/readiness smoke checks passed in Backend build run `42701716535` |
| PostgreSQL role grants and RLS | Disposable PostgreSQL 17 service container; bootstrap and operational security migrations applied to that disposable database only; least-privilege grant test passed |
| Station and assignee isolation | Real PostgreSQL harness passed station isolation, assigned-technician authorization, fault/support isolation, audit immutability, audited transitions, and rollback-on-audit-failure cases; fixtures rolled back |

## Remaining gaps — not represented as complete

| Risk / feature | Current state |
|---|---|
| Hosted Supabase schema drift | Not introspected; no hosted database connection used |
| Attachments and export isolation | No corresponding API routes are mapped in `Program.cs`; implementation and authorization tests remain outstanding |
| `operations.analytics.read` | Documented only; not wired to an API endpoint/policy |
| `legacy_users_staging` origin | Requires owner decision before any migration or use |
| Live authenticated staging E2E | Not run; requires operator-provisioned staging credentials and approved environment |
| Full Flutter/Angular UI parity with all legacy reports | Not established by these CI runs; requires screen-by-screen acceptance review |

## Disposable PostgreSQL harness

- `database/tests/ops_station_isolation_pg_test.sql` is an executable psql harness.
- It refuses any database other than `metra_ops_test`, requires the target operational tables to be empty, checks RLS and FORCE RLS, exercises station isolation and assignee authorization, and rolls fixtures back.
- It includes `database/tests/equipment_fault_npgsql_isolation.sql` and `database/tests/ops_assignee_authorization_pg_test.sql`.
- `database/tests/ops_role_grant_boundary_pg_test.sql` checks role flags, grants, client denials, RPC execute privileges, and audit boundaries.
- These tests now run in the automated disposable-PostgreSQL CI job. This is not a claim that hosted Supabase was inspected or changed.

## Security and release boundaries

- No PR merge.
- No SQL applied to any hosted database.
- No connection to, modification of, or migration from the legacy database.
- No production-readiness claim based solely on green CI.
- Attachments/export and analytics permissions must be implemented with station-scoped authorization, least-privilege storage access, audit coverage, and negative cross-station tests before release.

## Next work sequence

1. Define the attachment metadata/storage contract and export data scope from the approved new-project schema; do not assume or create hosted tables.
2. Implement authenticated attachment metadata/download/upload routes with station and record ownership checks, safe content validation, size limits, and audit events; test cross-station denial.
3. Define analytics query scope and wire `operations.analytics.read` to explicit policy and station/authority scoping; add allow/deny tests.
4. Resolve the provenance and intended disposition of `legacy_users_staging` with the owner.
5. Complete legacy-screen parity review and approved staging E2E.

