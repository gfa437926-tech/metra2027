#!/usr/bin/env bash
# Restore the complete checked-in METRA baseline + migrations into a disposable
# source PostgreSQL database, dump public/private, restore into a second empty
# database, then compare schema definitions and audit ACL/RLS across every table.
# This never accepts hosted Supabase URLs and never imports application history.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TRANSFER="$ROOT/database/transfer"
REAL_PSQL="$(command -v psql)"
REAL_CREATEDB="$(command -v createdb)"
REAL_DROPDB="$(command -v dropdb)"
REAL_PGDUMP="$(command -v pg_dump)"
SOURCE_DB="metra_actual_schema_source_$$"
TARGET_DB="metra_actual_schema_target_$$"
WORK="$(mktemp -d)"

for cmd in psql createdb dropdb pg_dump sed diff; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd is required." >&2; exit 2; }
done

export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"

cleanup() {
  "$REAL_DROPDB" --if-exists "$SOURCE_DB" >/dev/null 2>&1 || true
  "$REAL_DROPDB" --if-exists "$TARGET_DB" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# Ensure only local, non-login role names needed by the repository's schema
# migrations. This is idempotent because earlier CI steps may have created them.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d postgres <<'SQL'
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF;
END
$roles$;
DO $assert$
BEGIN
  IF NOT (SELECT rolbypassrls AND NOT rolsuper AND NOT rolcanlogin FROM pg_roles WHERE rolname='service_role') THEN
    RAISE EXCEPTION 'service_role fixture has unexpected role attributes';
  END IF;
END
$assert$;
SQL

"$REAL_CREATEDB" "$SOURCE_DB"
"$REAL_CREATEDB" "$TARGET_DB"

# Source: complete authoritative Path N build, not the generic transfer fixtures.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" -f "$TRANSFER/sql/bootstrap_target_roles.sql" >/dev/null
PATH_N_DATABASE_URL="postgresql://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$SOURCE_DB" \
PATH_N_APPLY_OBSERVATIONS=1 bash "$ROOT/database/baseline/path_n_apply.sh"

# Assert the schema pack was actually applied: baseline entities, all current
# migration-owned objects, and both operational observation tables must exist.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" <<'SQL'
DO $assert$
DECLARE
  required_name text;
  required_names text[] := ARRAY[
    'countries','meteorological_authorities','station_catalogue',
    'metra_role_catalogue','metra_permission_codes','metra_role_permissions',
    'metra_account_states','authority_memberships','station_assignments',
    'permission_grants','metra_user_profiles','registration_requests',
    'registration_audit_events','station_audit_log','permission_grant_audit',
    'authority_access_audit_events',
    'metra_observations','metra_observation_audit_events'
  ];
BEGIN
  FOREACH required_name IN ARRAY required_names LOOP
    IF to_regclass(format('public.%I', required_name)) IS NULL THEN
      RAISE EXCEPTION 'complete METRA schema build is missing public.%', required_name;
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='metra_submit_observation') THEN
    RAISE EXCEPTION 'operational observation submission RPC missing from full schema';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='metra_decide_observation') THEN
    RAISE EXCEPTION 'operational observation decision RPC missing from full schema';
  END IF;
END
$assert$;
SQL

# Target: recreate the reviewed target-side role/default ACL boundary while
# application schemas are empty. Auth is stubbed separately; Auth users are not
# exported/imported and the source stub contains no real identities.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$TRANSFER/sql/bootstrap_target_roles.sql" >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -c 'DROP SCHEMA private CASCADE' >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<'SQL'
CREATE SCHEMA auth;
CREATE TABLE auth.users (
  id uuid PRIMARY KEY,
  email text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE EXTENSION pgcrypto WITH SCHEMA public;
SQL

# Export and restore every checked-in public/private definition from the full
# Path N source. Source ACLs/owners are intentionally omitted and reviewed
# target grants are applied after restore.
"$REAL_PGDUMP" --format=plain --schema=public --schema=private --no-owner --no-privileges \
  --file="$WORK/actual-schema.sql" --dbname="$SOURCE_DB"
sed -e '/^SET transaction_timeout = 0;$/d' \
    -e '/^CREATE SCHEMA public;$/d' \
    "$WORK/actual-schema.sql" > "$WORK/actual-schema.compat.sql"
"$REAL_PSQL" -X -1 -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$WORK/actual-schema.compat.sql"

# First compare restored schema definitions before target-side ACL/search_path
# hardening. The transfer policy intentionally tightens runtime privileges and
# trigger search_path after the schema has been faithfully restored.

# Compare normalized schema-only dumps. This covers all restored table/column
# definitions, constraints, indexes, sequences, views, functions, triggers,
# RLS flags and policies in public/private, not a hand-picked table subset.
for side in source target; do
  db="$SOURCE_DB"
  [[ "$side" == target ]] && db="$TARGET_DB"
  "$REAL_PGDUMP" --schema-only --schema=public --schema=private --no-owner --no-privileges \
    --file="$WORK/$side.schema.sql" --dbname="$db"
  sed -e '/^--/d' -e '/^SET /d' -e '/^SELECT pg_catalog.set_config/d' \
      -e '/^\\restrict /d' -e '/^\\unrestrict /d' \
      -e '/^ALTER TABLE ONLY .* ALTER COLUMN .* SET (pg_attver=[0-9][0-9]*);$/d' \
      "$WORK/$side.schema.sql" | sed '/^[[:space:]]*$/d' > "$WORK/$side.schema.normalized.sql"
done
if ! diff -u "$WORK/source.schema.normalized.sql" "$WORK/target.schema.normalized.sql" > "$WORK/schema.diff"; then
  cat "$WORK/schema.diff" >&2
  echo "FAIL: full METRA public/private schema definitions changed during restore." >&2
  exit 1
fi

# Compare RLS enable/force state and complete policy definitions independently
# of pg_dump so the test reports policy drift explicitly.
for side in source target; do
  db="$SOURCE_DB"
  [[ "$side" == target ]] && db="$TARGET_DB"
  "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -At -F '|' -d "$db" <<'SQL' > "$WORK/$side.rls.txt"
SELECT n.nspname, c.relname, c.relrowsecurity, c.relforcerowsecurity,
       COALESCE(p.policyname,''), COALESCE(p.permissive::text,''),
       COALESCE(p.roles::text,''), COALESCE(p.cmd,''), COALESCE(p.qual,''),
       COALESCE(p.with_check,'')
FROM pg_class c
JOIN pg_namespace n ON n.oid=c.relnamespace
LEFT JOIN pg_policies p ON p.schemaname=n.nspname AND p.tablename=c.relname
WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p')
ORDER BY n.nspname,c.relname,p.policyname;
SQL
done
if ! diff -u "$WORK/source.rls.txt" "$WORK/target.rls.txt" > "$WORK/rls.diff"; then
  cat "$WORK/rls.diff" >&2
  echo "FAIL: RLS flags or policy definitions changed during full schema restore." >&2
  exit 1
fi

# Inventory all restored application objects. Counts are emitted to the CI log
# and are required to match exactly on source and target.
for side in source target; do
  db="$SOURCE_DB"
  [[ "$side" == target ]] && db="$TARGET_DB"
  "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -At -F '|' -d "$db" <<'SQL' > "$WORK/$side.inventory.txt"
SELECT 'tables', count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p')
UNION ALL
SELECT 'views', count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','private') AND c.relkind IN ('v','m')
UNION ALL
SELECT 'sequences', count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','private') AND c.relkind='S'
UNION ALL
SELECT 'indexes', count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','private') AND c.relkind='i'
UNION ALL
SELECT 'functions', count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname IN ('public','private')
   AND NOT EXISTS (
     SELECT 1 FROM pg_depend d
     WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid
       AND d.refclassid='pg_extension'::regclass AND d.deptype='e'
   )
UNION ALL
SELECT 'extension_functions:' || e.extname, count(*)
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
JOIN pg_depend d ON d.classid='pg_proc'::regclass AND d.objid=p.oid
  AND d.refclassid='pg_extension'::regclass AND d.deptype='e'
JOIN pg_extension e ON e.oid=d.refobjid
WHERE n.nspname IN ('public','private')
GROUP BY e.extname
UNION ALL
SELECT 'triggers', count(*) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
 JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','private') AND NOT t.tgisinternal
UNION ALL
SELECT 'constraints', count(*) FROM pg_constraint co JOIN pg_class c ON c.oid=co.conrelid
 JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname IN ('public','private');
SQL
done
diff -u "$WORK/source.inventory.txt" "$WORK/target.inventory.txt"
cat "$WORK/target.inventory.txt"

# Reapply the reviewed target ACL policy only after schema fidelity has been
# compared; this layer intentionally tightens target-side grants/search_path.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$TRANSFER/sql/apply_runtime_grants.sql" >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$TRANSFER/tests/assert_target_default_acl.sql" >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$TRANSFER/tests/assert_runtime_grants.sql" >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$TRANSFER/tests/assert_target_function_search_path.sql" >/dev/null

# Fail closed if any public/private table is directly exposed to anon or
# authenticated without RLS. Also require client roles to have no direct
# privileges on the operational observation tables and audit events.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<'SQL'
DO $audit$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p')
      AND NOT c.relrowsecurity
      AND (
        has_table_privilege('anon',c.oid,'SELECT')
        OR has_table_privilege('anon',c.oid,'INSERT')
        OR has_table_privilege('anon',c.oid,'UPDATE')
        OR has_table_privilege('anon',c.oid,'DELETE')
        OR has_table_privilege('authenticated',c.oid,'SELECT')
        OR has_table_privilege('authenticated',c.oid,'INSERT')
        OR has_table_privilege('authenticated',c.oid,'UPDATE')
        OR has_table_privilege('authenticated',c.oid,'DELETE')
      )
  ) THEN RAISE EXCEPTION 'client-granted table exists without RLS in restored METRA schema'; END IF;

  IF EXISTS (
    SELECT 1 FROM (VALUES
      ('public.metra_observations'::regclass),
      ('public.metra_observation_audit_events'::regclass)
    ) AS t(relid)
    WHERE has_table_privilege('anon',relid,'SELECT')
       OR has_table_privilege('anon',relid,'INSERT')
       OR has_table_privilege('anon',relid,'UPDATE')
       OR has_table_privilege('anon',relid,'DELETE')
       OR has_table_privilege('authenticated',relid,'SELECT')
       OR has_table_privilege('authenticated',relid,'INSERT')
       OR has_table_privilege('authenticated',relid,'UPDATE')
       OR has_table_privilege('authenticated',relid,'DELETE')
  ) THEN RAISE EXCEPTION 'client role has direct operational observation table privileges'; END IF;

  IF EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p')
      AND (has_table_privilege('anon',c.oid,'TRUNCATE')
        OR has_table_privilege('anon',c.oid,'REFERENCES')
        OR has_table_privilege('anon',c.oid,'TRIGGER')
        OR has_table_privilege('authenticated',c.oid,'TRUNCATE')
        OR has_table_privilege('authenticated',c.oid,'REFERENCES')
        OR has_table_privilege('authenticated',c.oid,'TRIGGER'))
  ) THEN RAISE EXCEPTION 'client role has elevated table ACL in restored METRA schema'; END IF;
END
$audit$;
SQL

echo "PASS: restored the complete checked-in METRA baseline and migration schema."
echo "PASS: source/target schema definitions, object counts, RLS flags and policies match."
echo "PASS: all restored public/private tables passed the client ACL/RLS audit."
echo "PASS: disposable PostgreSQL only; no hosted database or historical observation data used."
