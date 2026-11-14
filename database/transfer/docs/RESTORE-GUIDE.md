# Full restore guide (experimental source)

## Goal

Rebuild a database that matches the experimental project `tbdnklyxjvbrilvnwgmq` export without depending on the live project remaining online.

## Inputs

1. Export directory from `scripts/01_export_source.sh` containing:
   - `01_schema_public.sql`
   - `02_data_public.sql`
   - optional `01_schema_auth.sql` / auth data
   - `MANIFEST.txt`
2. Empty Postgres 15+ compatible instance (local, or new Supabase project).

## Steps

```bash
export METRA_DST_DATABASE_URL='postgresql://...'
export METRA_DST_PROJECT_REF='your-new-ref'

# 1. Schema
bash database/transfer/scripts/03_import_schema.sh /path/to/export_stamp

# 2. Data
bash database/transfer/scripts/04_import_data.sh /path/to/export_stamp

# 3. Auth (if included)
# psql "$METRA_DST_DATABASE_URL" -v ON_ERROR_STOP=1 -f /path/to/auth_users_data.sql

# 4. Analyze
psql "$METRA_DST_DATABASE_URL" -c 'ANALYZE;'

# 5. Compare against source if still online
export METRA_SRC_DATABASE_URL='postgresql://...'
bash database/transfer/scripts/05_compare.sh
```

## Acceptance

- Table list matches inventory.
- Row counts for catalogue and experimental tables match within documented deltas.
- Foreign keys validate.
- Application can authenticate against **new** Auth configuration only.

## Rollback

Keep the experimental project `tbdnklyxjvbrilvnwgmq` online until:

1. At least one full restore into a second environment succeeds.
2. Compare report is archived.
3. Owner signs off.

This pack never issues `DROP` against the source project.
