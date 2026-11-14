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
REAL_PGRESTORE="$(command -v pg_restore)"
SOURCE_DB="metra_restore_acl_source_$$"
TARGET_DB="metra_restore_acl_target_$$"
WORK="$(mktemp -d)"
OWNER_ID="11111111-1111-4111-8111-111111111111"
OTHER_ID="22222222-2222-4222-8222-222222222222"

for cmd in psql createdb dropdb pg_dump pg_restore; do
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
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" <<SQL
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
INSERT INTO auth.users(id) VALUES ('$OWNER_ID'), ('$OTHER_ID');
CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
SQL

# Export/import only application schemas, with ownership and source ACLs
# intentionally excluded; reviewed target grants are reapplied afterwards.
"$REAL_PGDUMP" --format=custom --schema=public --schema=private --no-owner --no-privileges \
  --file="$WORK/application.dump" --dbname="$SOURCE_DB"
"$REAL_PGRESTORE" --exit-on-error --no-owner --no-privileges \
  --dbname="$TARGET_DB" "$WORK/application.dump"

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

# Grant only the test table's reviewed client DML privileges after restore;
# the RLS policies must then enforce row-level isolation.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" \
  -c 'GRANT SELECT, INSERT, UPDATE, DELETE ON public.restore_policy_fixture TO authenticated' >/dev/null

visible="$("$REAL_PSQL" -X -v ON_ERROR_STOP=1 -At -d "$TARGET_DB" \
  -c "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','$OWNER_ID',false); SELECT count(*) FROM public.restore_policy_fixture" | tail -n 1)"
[[ "$visible" == "1" ]] || { echo "FAIL: restored SELECT policy leaked or hid owner rows (count=$visible)." >&2; exit 1; }

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
