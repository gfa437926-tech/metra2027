#!/usr/bin/env bash
# Isolated RLS/ACL matrix against a disposable schema in the CI PostgreSQL service.
# This test never accepts a Supabase URL and uses only the configured local PG connection.
set -euo pipefail

command -v psql >/dev/null 2>&1 || { echo "FAIL: psql is required." >&2; exit 2; }
DB="${PGDATABASE:-postgres}"
SCHEMA="rls_acl_matrix_$$"
OWNER_ID="11111111-1111-4111-8111-111111111111"
OTHER_ID="22222222-2222-4222-8222-222222222222"

cleanup() {
  psql -X -v ON_ERROR_STOP=1 -d "$DB" -c "DROP SCHEMA IF EXISTS $SCHEMA CASCADE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Managed role fixtures are provisioned by the preceding isolated CI setup step.\npsql -X -v ON_ERROR_STOP=1 -d "$DB" <<SQL
CREATE SCHEMA $SCHEMA;
CREATE TABLE $SCHEMA.station_records (
  id integer PRIMARY KEY, station_id integer NOT NULL,
  owner_id uuid NOT NULL, payload text NOT NULL
);
INSERT INTO $SCHEMA.station_records VALUES
  (1, 10, '$OWNER_ID', 'owner-row'),
  (2, 20, '$OTHER_ID', 'other-row');
ALTER TABLE $SCHEMA.station_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE $SCHEMA.station_records FORCE ROW LEVEL SECURITY;
CREATE POLICY station_select_own ON $SCHEMA.station_records
  FOR SELECT TO authenticated USING (owner_id = $SCHEMA.current_user_id());
CREATE POLICY station_insert_own ON $SCHEMA.station_records
  FOR INSERT TO authenticated WITH CHECK (owner_id = $SCHEMA.current_user_id());
CREATE POLICY station_update_own ON $SCHEMA.station_records
  FOR UPDATE TO authenticated USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());
CREATE POLICY station_delete_own ON $SCHEMA.station_records
  FOR DELETE TO authenticated USING (owner_id = auth.uid());
GRANT USAGE ON SCHEMA $SCHEMA TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON $SCHEMA.station_records TO authenticated, service_role;
SQL

# ACL denial for anon is distinct from RLS row filtering.
if psql -X -v ON_ERROR_STOP=1 -d "$DB" -c "SET ROLE anon; SELECT * FROM $SCHEMA.station_records" > /tmp/metra-rls-anon.log 2>&1; then
  echo "FAIL: anon unexpectedly accessed the protected station table." >&2; exit 1
fi
grep -Eqi 'permission denied|does not exist' /tmp/metra-rls-anon.log

visible="$(psql -X -v ON_ERROR_STOP=1 -At -d "$DB" -c "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','$OWNER_ID',false); SELECT count(*) FROM $SCHEMA.station_records")"
[[ "$(printf '%s\n' "$visible" | tail -n 1)" == "1" ]] || {
  echo "FAIL: authenticated SELECT did not enforce owner isolation." >&2; exit 1;
}

if psql -X -v ON_ERROR_STOP=1 -d "$DB" -c "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','$OWNER_ID',false); INSERT INTO $SCHEMA.station_records VALUES (3,30,'$OTHER_ID','forged')" > /tmp/metra-rls-insert.log 2>&1; then
  echo "FAIL: RLS accepted an INSERT for another owner." >&2; exit 1
fi
grep -Fqi 'row-level security policy' /tmp/metra-rls-insert.log

if psql -X -v ON_ERROR_STOP=1 -d "$DB" -c "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','$OWNER_ID',false); UPDATE $SCHEMA.station_records SET owner_id='$OTHER_ID' WHERE id=1" > /tmp/metra-rls-update.log 2>&1; then
  echo "FAIL: RLS accepted cross-owner reassignment." >&2; exit 1
fi
grep -Fqi 'row-level security policy' /tmp/metra-rls-update.log

deleted="$(psql -X -v ON_ERROR_STOP=1 -At -d "$DB" -c "SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','$OWNER_ID',false); WITH gone AS (DELETE FROM $SCHEMA.station_records WHERE id IN (1,2) RETURNING id) SELECT count(*) FROM gone")"
[[ "$(printf '%s\n' "$deleted" | tail -n 1)" == "1" ]] || {
  echo "FAIL: DELETE did not restrict access to the caller's row." >&2; exit 1;
}

service_rows="$(psql -X -v ON_ERROR_STOP=1 -At -d "$DB" -c "SET ROLE service_role; SELECT count(*) FROM $SCHEMA.station_records")"
[[ "$(printf '%s\n' "$service_rows" | tail -n 1)" == "1" ]] || {
  echo "FAIL: service_role did not retain server-side RLS bypass for remaining rows." >&2; exit 1;
}

psql -X -v ON_ERROR_STOP=1 -d "$DB" <<'SQL'
DO $assertions$
BEGIN
  IF has_schema_privilege('anon','private','USAGE') THEN RAISE EXCEPTION 'anon has private schema USAGE'; END IF;
  IF has_schema_privilege('authenticated','private','USAGE') THEN RAISE EXCEPTION 'authenticated has private schema USAGE'; END IF;
  IF NOT has_schema_privilege('metra_api_runtime','private','USAGE') THEN RAISE EXCEPTION 'runtime role lacks private schema USAGE'; END IF;
  IF (SELECT rolsuper OR rolbypassrls OR rolcanlogin OR rolcreaterole OR rolcreatedb
      FROM pg_roles WHERE rolname='metra_api_runtime') THEN RAISE EXCEPTION 'runtime role has unsafe attributes'; END IF;
  IF NOT pg_has_role('postgres','metra_api_runtime','MEMBER') THEN RAISE EXCEPTION 'postgres lacks runtime role membership'; END IF;
END
$assertions$;
SQL

echo "PASS: isolated ACL/RLS matrix (anon denial, authenticated row isolation, INSERT/UPDATE WITH CHECK, DELETE scoping, service_role bypass, private-schema separation, and runtime-role posture)."
