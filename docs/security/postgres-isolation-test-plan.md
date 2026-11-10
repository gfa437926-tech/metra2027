# PostgreSQL isolation test plan (review only — do not apply)

## Goal
Prove that `SET LOCAL app.station_id` / `app.user_id` and RLS policies prevent cross-station reads/writes for equipment faults and support incidents **without** using the legacy database or production data.

## Constraints
- No connection to the old METRA database.
- No apply of migrations to the hosted new Supabase project until owner approval.
- Prefer an **ephemeral local Postgres** or disposable CI service container.

## Prerequisites (after owner approval only)
1. Provision empty Postgres 15+.
2. Apply **only** the reviewed scripts from `supabase/migrations` and `database/migrations` that define ops tables/roles/RLS (in filename order).
3. Create limited role matching `metra_ops_faults` / session settings expected by `NpgsqlOpsSession`.
4. Seed two stations (A, B), two users, grants only on A for user1.

## Assertions
1. Connection as ops role with `app.station_id = A` can select faults for A only.
2. Same connection cannot select station B rows even if UUID is known.
3. `UPDATE`/`transition` with station B id fails or affects 0 rows.
4. Missing `SET LOCAL` yields no rows (deny by default) if RLS is enforced.
5. Audit tables reject UPDATE/DELETE if triggers exist as designed.

## Proposed automated harness (files for review)
- `database/tests/ops_station_isolation_pg_test.sql` — declarative SQL expectations for a disposable DB.
- Optional later: .NET test conditioned on `METRA_OPS_TEST_DATABASE_URL` (never default to production).

## Explicit non-goals
- Importing legacy stations or users.
- Running against `tbdnklyxjvbrilvnwgmq` without written approval.
