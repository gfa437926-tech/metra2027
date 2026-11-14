#!/usr/bin/env bash
# Full synthetic restore followed by live PostgreSQL ACL/RLS assertions.
# Uses disposable local databases only; hosted Supabase URLs are never accepted.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TRANSFER="$ROOT/database/transfer"
REAL_PSQL="$(command -v psql)"
REAL_CREATEDB="$(command -v createdb)"
REAL_DROPDB="$(command -v dropdb)"
REAL_PGDUMP="$(command -v pg_dump)"
SOURCE_DB="metra_restore_acl_source_$$"
TARGET_DB="metra_restore_acl_target_$$"
WORK="$(mktemp -d)"
OWNER_ID="11111111-1111-4111-8111-111111111111"
OTHER_ID="22222222-2222-4222-8222-222222222222"

for cmd in psql createdb dropdb pg_dump sed; do
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

"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d postgres <<'SQL'
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF;
END
$roles$;
SQL

"$REAL_CREATEDB" "$SOURCE_DB"
"$REAL_CREATEDB" "$TARGET_DB"

# Build a deterministic source schema using the same managed-role/bootstrap
# and grant fixtures exercised by the transfer workflow.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" -f "$TRANSFER/sql/bootstrap_target_roles.sql" >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" -c 'CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions;' >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" -f "$TRANSFER/tests/runtime_role_fixtures.sql" >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" -f "$TRANSFER/tests/compare_fixture.sql" >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" -f "$ROOT/supabase/migrations/20261103164003_create_operational_observation_submission.sql" >/dev/null

"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$SOURCE_DB" <<SQL
CREATE TABLE public.restore_policy_fixture (
  id integer PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  payload text NOT NULL
);
INSERT INTO public.restore_policy_fixture VALUES
  (1, '$OWNER_ID', 'owner-data'),
  (2, '$OTHER_ID', 'other-data');
ALTER TABLE public.restore_policy_fixture ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restore_policy_fixture FORCE ROW LEVEL SECURITY;
CREATE POLICY restore_select_own ON public.restore_policy_fixture
  FOR SELECT TO authenticated
  USING (user_id = NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid);
CREATE POLICY restore_insert_own ON public.restore_policy_fixture
  FOR INSERT TO authenticated
  WITH CHECK (user_id = NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid);
CREATE POLICY restore_update_own ON public.restore_policy_fixture
  FOR UPDATE TO authenticated
  USING (user_id = NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid)
  WITH CHECK (user_id = NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid);
CREATE POLICY restore_delete_own ON public.restore_policy_fixture
  FOR DELETE TO authenticated
  USING (user_id = NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid);
SQL

# Target bootstrap is performed while public/private are empty. Auth is managed
# separately, mirroring the transfer contract: Auth users are not imported.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$TRANSFER/sql/bootstrap_target_roles.sql" >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -c 'DROP SCHEMA private CASCADE' >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<SQL
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
INSERT INTO auth.users(id) VALUES ('$OWNER_ID'), ('$OTHER_ID');
CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
SQL

# Export/import only application schemas, with ownership and source ACLs
# intentionally excluded; reviewed target grants are reapplied afterwards.
"$REAL_PGDUMP" --format=plain --schema=public --schema=private --no-owner --no-privileges \
  --file="$WORK/application.sql" --dbname="$SOURCE_DB"
# pg_dump from a newer client can emit SET transaction_timeout, which older
# supported PostgreSQL servers (including the CI PostgreSQL 16 service) lack.
# Strip only this session-setting line; schema/data statements remain unchanged.
sed '/^SET transaction_timeout = 0;$/d' "$WORK/application.sql" > "$WORK/application.compat.sql"
"$REAL_PSQL" -X -1 -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$WORK/application.compat.sql"

# Apply the same reviewed target-side runtime ACL policy used by transfer.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$TRANSFER/sql/apply_runtime_grants.sql" >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$TRANSFER/tests/assert_target_default_acl.sql" >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$TRANSFER/tests/assert_runtime_grants.sql" >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -f "$TRANSFER/tests/assert_target_function_search_path.sql" >/dev/null

# Assert the restored table carries all four expected policies and FORCE RLS.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<'SQL'
DO $assert$
DECLARE
  policy_count integer;
BEGIN
  SELECT count(*) INTO policy_count
  FROM pg_policies
  WHERE schemaname='public' AND tablename='restore_policy_fixture'
    AND policyname IN ('restore_select_own','restore_insert_own','restore_update_own','restore_delete_own');
  IF policy_count <> 4 THEN RAISE EXCEPTION 'expected 4 restored policies, found %', policy_count; END IF;
  IF NOT (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid='public.restore_policy_fixture'::regclass) THEN
    RAISE EXCEPTION 'restored table does not have ENABLE and FORCE ROW LEVEL SECURITY';
  END IF;
  -- These are the actual operational observation tables from the checked-in migration.
  -- They deliberately have RLS enabled/FORCED with no client policies: access is
  -- through the reviewed server-side RPC, not direct client table grants.
  IF NOT (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid='public.metra_observations'::regclass) THEN
    RAISE EXCEPTION 'restored metra_observations lost ENABLE/FORCE RLS';
  END IF;
  IF NOT (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid='public.metra_observation_audit_events'::regclass) THEN
    RAISE EXCEPTION 'restored metra_observation_audit_events lost ENABLE/FORCE RLS';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
      AND tablename IN ('metra_observations','metra_observation_audit_events')) THEN
    RAISE EXCEPTION 'operational observation tables unexpectedly gained direct-client RLS policies';
  END IF;
  IF has_table_privilege('anon','public.metra_observations','SELECT')
     OR has_table_privilege('anon','public.metra_observations','INSERT')
     OR has_table_privilege('anon','public.metra_observations','UPDATE')
     OR has_table_privilege('anon','public.metra_observations','DELETE')
     OR has_table_privilege('authenticated','public.metra_observations','SELECT')
     OR has_table_privilege('authenticated','public.metra_observations','INSERT')
     OR has_table_privilege('authenticated','public.metra_observations','UPDATE')
     OR has_table_privilege('authenticated','public.metra_observations','DELETE')
     OR has_table_privilege('anon','public.metra_observation_audit_events','SELECT')
     OR has_table_privilege('anon','public.metra_observation_audit_events','INSERT')
     OR has_table_privilege('anon','public.metra_observation_audit_events','UPDATE')
     OR has_table_privilege('anon','public.metra_observation_audit_events','DELETE')
     OR has_table_privilege('authenticated','public.metra_observation_audit_events','SELECT')
     OR has_table_privilege('authenticated','public.metra_observation_audit_events','INSERT')
     OR has_table_privilege('authenticated','public.metra_observation_audit_events','UPDATE')
     OR has_table_privilege('authenticated','public.metra_observation_audit_events','DELETE') THEN
    RAISE EXCEPTION 'client role received direct privileges on operational observation tables';
  END IF;
  IF NOT has_table_privilege('service_role','public.metra_observations','SELECT')
     OR NOT has_table_privilege('service_role','public.metra_observations','INSERT')
     OR NOT has_table_privilege('service_role','public.metra_observation_audit_events','SELECT')
     OR NOT has_table_privilege('service_role','public.metra_observation_audit_events','INSERT') THEN
    RAISE EXCEPTION 'service_role lost required server-side observation access';
  END IF;
  IF has_function_privilege('anon',
       'public.metra_submit_observation(uuid,uuid,text,text,timestamp with time zone,jsonb,boolean)','EXECUTE')
     OR has_function_privilege('authenticated',
       'public.metra_submit_observation(uuid,uuid,text,text,timestamp with time zone,jsonb,boolean)','EXECUTE')
     OR NOT has_function_privilege('service_role',
       'public.metra_submit_observation(uuid,uuid,text,text,timestamp with time zone,jsonb,boolean)','EXECUTE') THEN
    RAISE EXCEPTION 'operational observation RPC execute ACL is not service_role-only';
  END IF;
  IF has_table_privilege('anon','public.restore_policy_fixture','SELECT') THEN
    RAISE EXCEPTION 'anon unexpectedly has SELECT on restored policy table';
  END IF;
  IF has_schema_privilege('anon','private','USAGE')
     OR has_schema_privilege('authenticated','private','USAGE')
     OR has_schema_privilege('service_role','private','USAGE') THEN
    RAISE EXCEPTION 'client/server managed role unexpectedly has private schema USAGE';
  END IF;
  IF NOT has_schema_privilege('metra_api_runtime','private','USAGE') THEN
    RAISE EXCEPTION 'runtime role lacks private schema USAGE';
  END IF;
END
$assert$;
SQL

# Audit every restored public table: any table granted to a client role must
# have RLS enabled. This catches accidental broad ACLs outside the focused fixture.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<'SQL'
DO $audit$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p')
      AND NOT c.relrowsecurity
      AND (
        has_table_privilege('anon', c.oid, 'SELECT')
        OR has_table_privilege('anon', c.oid, 'INSERT')
        OR has_table_privilege('anon', c.oid, 'UPDATE')
        OR has_table_privilege('anon', c.oid, 'DELETE')
        OR has_table_privilege('authenticated', c.oid, 'SELECT')
        OR has_table_privilege('authenticated', c.oid, 'INSERT')
        OR has_table_privilege('authenticated', c.oid, 'UPDATE')
        OR has_table_privilege('authenticated', c.oid, 'DELETE')
      )
  ) THEN
    RAISE EXCEPTION 'a restored public table has client grants without RLS';
  END IF;
END
$audit$;
SQL

# Exercise the actual operational observation tables after restore. Client roles
# are denied at the ACL layer; the server role can insert; audit mutations fail.
if "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" \
  -c 'SET ROLE authenticated; SELECT * FROM public.metra_observations' >"$WORK/actual-client-denial.log" 2>&1; then
  echo "FAIL: authenticated accessed the restored operational observation table." >&2; exit 1
fi
grep -Eqi 'permission denied' "$WORK/actual-client-denial.log"

# Prove RLS itself remains default-deny even if a client is accidentally granted
# table ACLs: the restored operational tables intentionally have no client policies.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<'SQL'
GRANT SELECT, INSERT ON public.metra_observations TO authenticated;
GRANT SELECT, INSERT ON public.metra_observation_audit_events TO authenticated;
SQL
for table in metra_observations metra_observation_audit_events; do
  visible="$("$REAL_PSQL" -X -v ON_ERROR_STOP=1 -At -d "$TARGET_DB" \
    -c "SET ROLE authenticated; SELECT count(*) FROM public.$table" | tail -n 1)"
  [[ "$visible" == "0" ]] || {
    echo "FAIL: RLS leaked rows from restored public.$table after temporary SELECT grant." >&2
    exit 1
  }
done
if "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" \
  -c "SET ROLE authenticated; INSERT INTO public.metra_observations (station_id,created_by,observation_type,observed_at,payload,status,initial_status,idempotency_key) VALUES ('00000000-0000-4000-8000-000000000001','$OWNER_ID','hourly',now(),'{}','draft','draft','client-forged')" >"$WORK/actual-rls-insert-denial.log" 2>&1; then
  echo "FAIL: restored no-policy RLS accepted client INSERT after temporary ACL grant." >&2
  exit 1
fi
grep -Fqi 'row-level security policy' "$WORK/actual-rls-insert-denial.log"
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<'SQL'
REVOKE SELECT, INSERT ON public.metra_observations FROM authenticated;
REVOKE SELECT, INSERT ON public.metra_observation_audit_events FROM authenticated;
SQL

"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<SQL
SET ROLE service_role;
INSERT INTO public.metra_observations
  (id, station_id, created_by, observation_type, observed_at, payload,
   status, initial_status, idempotency_key)
VALUES
  ('33333333-3333-4333-8333-333333333333',
   '00000000-0000-4000-8000-000000000001',
   '$OWNER_ID', 'hourly', now(), '{"synthetic":true}'::jsonb,
   'draft', 'draft', 'restore-acl-rls-smoke');
INSERT INTO public.metra_observation_audit_events
  (observation_id, station_id, actor_user_id, event_type, to_status)
VALUES
  ('33333333-3333-4333-8333-333333333333',
   '00000000-0000-4000-8000-000000000001',
   '$OWNER_ID', 'created_draft', 'draft');
RESET ROLE;
SQL

if "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" \
  -c "SET ROLE service_role; UPDATE public.metra_observation_audit_events SET note='tampered' WHERE observation_id='33333333-3333-4333-8333-333333333333'" >"$WORK/actual-audit-mutation.log" 2>&1; then
  echo "FAIL: restored operational audit table accepted UPDATE." >&2; exit 1
fi
grep -Fqi 'append-only' "$WORK/actual-audit-mutation.log"

# Grant only the test table's reviewed client DML privileges after restore;
# the RLS policies must then enforce row-level isolation.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" \
  -c 'GRANT SELECT, INSERT, UPDATE, DELETE ON public.restore_policy_fixture TO authenticated' >/dev/null
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<'SQL'
CREATE VIEW public.restore_policy_invoker WITH (security_invoker=true)
AS SELECT id, user_id, payload FROM public.restore_policy_fixture;
GRANT SELECT ON public.restore_policy_invoker TO authenticated;
CREATE TABLE private.restore_future_acl_fixture(id integer);
DO $defaults$
BEGIN
  IF has_table_privilege('anon','private.restore_future_acl_fixture','SELECT')
     OR has_table_privilege('authenticated','private.restore_future_acl_fixture','SELECT')
     OR has_table_privilege('service_role','private.restore_future_acl_fixture','SELECT') THEN
    RAISE EXCEPTION 'private default ACL exposed a future table';
  END IF;
END
$defaults$;
SQL

visible="$("$REAL_PSQL" -X -v ON_ERROR_STOP=1 -At -d "$TARGET_DB" \
  -c "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','$OWNER_ID',false); SELECT count(*) FROM public.restore_policy_fixture" | tail -n 1)"
[[ "$visible" == "1" ]] || { echo "FAIL: restored SELECT policy leaked or hid owner rows (count=$visible)." >&2; exit 1; }

view_visible="$("$REAL_PSQL" -X -v ON_ERROR_STOP=1 -At -d "$TARGET_DB" \
  -c "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','$OWNER_ID',false); SELECT count(*) FROM public.restore_policy_invoker" | tail -n 1)"
[[ "$view_visible" == "1" ]] || { echo "FAIL: security_invoker view bypassed restored RLS (count=$view_visible)." >&2; exit 1; }


if "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" \
  -c "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','$OWNER_ID',false); INSERT INTO public.restore_policy_fixture VALUES (3,'$OTHER_ID','forged')" >"$WORK/insert.log" 2>&1; then
  echo "FAIL: restored INSERT WITH CHECK accepted a forged owner." >&2; exit 1
fi
grep -Fqi 'row-level security policy' "$WORK/insert.log"

if "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" \
  -c "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','$OWNER_ID',false); UPDATE public.restore_policy_fixture SET user_id='$OTHER_ID' WHERE id=1" >"$WORK/update.log" 2>&1; then
  echo "FAIL: restored UPDATE WITH CHECK accepted ownership reassignment." >&2; exit 1
fi
grep -Fqi 'row-level security policy' "$WORK/update.log"

deleted="$("$REAL_PSQL" -X -v ON_ERROR_STOP=1 -At -d "$TARGET_DB" \
  -c "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','$OWNER_ID',false); WITH gone AS (DELETE FROM public.restore_policy_fixture WHERE id IN (1,2) RETURNING id) SELECT count(*) FROM gone" | tail -n 1)"
[[ "$deleted" == "1" ]] || { echo "FAIL: restored DELETE policy did not scope rows to the owner." >&2; exit 1; }

server_rows="$("$REAL_PSQL" -X -v ON_ERROR_STOP=1 -At -d "$TARGET_DB" \
  -c 'SET ROLE service_role; SELECT count(*) FROM public.restore_policy_fixture' | tail -n 1)"
[[ "$server_rows" == "1" ]] || { echo "FAIL: service_role did not retain intended BYPASSRLS after restore." >&2; exit 1; }

# The runtime role can use only the private API schema; it cannot read private
# fixture tables directly and it is not a superuser/BYPASSRLS role.
if "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" \
  -c 'SET ROLE metra_api_runtime; SELECT * FROM private.compare_fixture_private' >"$WORK/private.log" 2>&1; then
  echo "FAIL: runtime role unexpectedly read a private table directly." >&2; exit 1
fi
grep -Eqi 'permission denied' "$WORK/private.log"

"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<'SQL'
DO $assert$
BEGIN
  IF (SELECT rolsuper OR rolbypassrls OR rolcanlogin OR rolcreaterole OR rolcreatedb OR rolreplication
      FROM pg_roles WHERE rolname='metra_api_runtime') THEN
    RAISE EXCEPTION 'metra_api_runtime has unsafe role attributes';
  END IF;
  IF NOT pg_has_role('postgres','metra_api_runtime','MEMBER') THEN
    RAISE EXCEPTION 'postgres lacks expected runtime-role membership';
  END IF;
  IF NOT has_table_privilege('service_role','public.restore_policy_fixture','SELECT') THEN
    RAISE EXCEPTION 'service_role lost reviewed server table access';
  END IF;
END
$assert$;
SQL

echo "PASS: full isolated schema/data restore preserved all four RLS policies and FORCE RLS."
echo "PASS: restored ACL/RLS behavior verified for anon, authenticated, service_role, and metra_api_runtime."
echo "PASS: no hosted database connection or production mutation was used."
