# Applying migrations (NEW METRA only)

## Approval scope

Operator approved applying migrations for the **new METRA Supabase project only**, and enabling `ConnectionStrings:MetraOps` for the **test environment**.

Never apply these scripts against the legacy INSERT database.

## Local / CI isolated test (already automated)

```bash
export METRA_OPS_DATABASE_URL='postgresql://postgres:postgres@127.0.0.1:5432/metra_ops_test'
export METRA_APPLY_BOOTSTRAP=1
bash database/scripts/apply_new_metra_migrations.sh
```

Backend Development uses:

`ConnectionStrings:MetraOps` in `appsettings.Development.json` (local test credentials only).

## Hosted NEW Supabase project

1. Obtain the **database** connection string for project `tbdnklyxjvbrilvnwgmq` (Settings → Database).
2. Set a secret/env var on the API host or CI:

```bash
export METRA_OPS_DATABASE_URL='postgresql://postgres.[ref]:[PASSWORD]@aws-0-....pooler.supabase.com:6543/postgres'
# Bootstrap is NOT required on a real Supabase project (auth + catalogue already exist).
export METRA_APPLY_BOOTSTRAP=0
bash database/scripts/apply_new_metra_migrations.sh
```

3. Configure the API:

```text
ConnectionStrings__MetraOps=<same URI or Npgsql form>
Supabase__Url=https://tbdnklyxjvbrilvnwgmq.supabase.co
Supabase__ServiceRoleKey=<server only>
```

The apply script aborts if the URL looks legacy (`legacy`, `insert`, `old-metra`) unless forced.

## Status

- All current `supabase/migrations/*.sql` files were applied successfully on an isolated local `metra_ops_test` database.
- Hosted apply requires the operator-provided DB password / `METRA_OPS_DATABASE_URL` (not stored in the repository).
