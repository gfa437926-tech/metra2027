# PostgreSQL isolation test plan (review only — do not apply to hosted DB)

## Harness file
`database/tests/ops_station_isolation_pg_test.sql`

## What it proves on an empty disposable Postgres
- FORCE ROW LEVEL SECURITY on test fault/incident tables
- `app.station_id` / `app.user_id` session GUCs (same names used by `NpgsqlOpsSession`)
- Cross-station SELECT counts must be 0 or the script raises `*_CROSS_STATION_FAIL`
- Empty context must see 0 rows

## How to run (owner-approved local only)
```bash
# Example only — never point at production or legacy:
createdb metra_ops_isolation_tmp
psql "$METRA_OPS_TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/ops_station_isolation_pg_test.sql
dropdb metra_ops_isolation_tmp
```

## Explicit bans
- Do not run against the legacy METRA database
- Do not run against hosted Supabase until written approval
- This script is self-contained for isolation mechanics; it does not replace production migrations
