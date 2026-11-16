#!/usr/bin/env bash
# End-to-end regression for 05_compare.sh using two disposable local PostgreSQL
# databases. Supabase-shaped URLs are intercepted by a strict local-only psql
# shim; no hosted database or network endpoint is ever contacted.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TRANSFER_ROOT="$ROOT/database/transfer"
RUNNER="$TRANSFER_ROOT/scripts/05_compare.sh"
REAL_PSQL="$(command -v psql)"
REAL_CREATEDB="$(command -v createdb)"
REAL_DROPDB="$(command -v dropdb)"
WORK_DIR="$(mktemp -d)"
SOURCE_DB="metra_cmp_source_$$"
TARGET_DB="metra_cmp_target_$$"
SOURCE_REF="tbdnklyxjvbrilvnwgmq"
TARGET_REF="syntheticmetratarget12345678"
ORIGINAL_PATH="$PATH"

for command_name in psql createdb dropdb; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "FAIL: $command_name is required for isolated comparison tests." >&2
    exit 2
  }
done

export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export METRA_SRC_PROJECT_REF="$SOURCE_REF"
export METRA_DST_PROJECT_REF="$TARGET_REF"
export METRA_SRC_DATABASE_URL="postgresql://postgres:ci-only@db.$SOURCE_REF.supabase.co:5432/postgres"
export METRA_DST_DATABASE_URL="postgresql://postgres:ci-only@db.$TARGET_REF.supabase.co:5432/postgres"
export METRA_COMPARE_SOURCE_DB="$SOURCE_DB"
export METRA_COMPARE_TARGET_DB="$TARGET_DB"
export METRA_COMPARE_REAL_PSQL="$REAL_PSQL"
export METRA_COMPARE_TEST_MODE=1

cleanup() {
  PATH="$ORIGINAL_PATH" "$REAL_DROPDB" --if-exists "$SOURCE_DB" >/dev/null 2>&1 || true
  PATH="$ORIGINAL_PATH" "$REAL_DROPDB" --if-exists "$TARGET_DB" >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# Roles are cluster-wide. Create only missing Supabase-compatible fixture roles.
"$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d postgres <<'SQL'
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
    EXECUTE 'CREATE ROLE anon NOLOGIN';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN
    EXECUTE 'CREATE ROLE authenticated NOLOGIN';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN
    EXECUTE 'CREATE ROLE service_role NOLOGIN BYPASSRLS';
  END IF;
END
$roles$;
SQL

"$REAL_CREATEDB" "$SOURCE_DB"
"$REAL_CREATEDB" "$TARGET_DB"

setup_database() {
  local database="$1"
  "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$database" \
    -f "$TRANSFER_ROOT/sql/bootstrap_target_roles.sql" >/dev/null
  "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$database" \
    -c 'CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions;' >/dev/null
  "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$database" \
    -f "$TRANSFER_ROOT/tests/runtime_role_fixtures.sql" >/dev/null
  "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$database" \
    -f "$TRANSFER_ROOT/tests/compare_fixture.sql" >/dev/null
  "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$database" \
    -f "$TRANSFER_ROOT/sql/apply_runtime_grants.sql" >/dev/null
  "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$database" \
    -f "$TRANSFER_ROOT/tests/assert_target_default_acl.sql" >/dev/null
  "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$database" \
    -f "$TRANSFER_ROOT/tests/assert_target_function_search_path.sql" >/dev/null
}

setup_database "$SOURCE_DB"
setup_database "$TARGET_DB"

# A deliberately strict adapter: only the two synthetic project identities
# are accepted, and both are routed to loopback PostgreSQL databases.
mkdir -p "$WORK_DIR/bin"
cat > "$WORK_DIR/bin/psql" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
[[ "${METRA_COMPARE_TEST_MODE:-}" == "1" ]] || {
  echo "Refusing: local comparison psql shim is disabled." >&2
  exit 90
}
connection="${1:-}"
[[ -n "$connection" ]] || {
  echo "Refusing: comparison runner omitted its connection URL." >&2
  exit 91
}
shift
case "$connection" in
  *"@db.${METRA_SRC_PROJECT_REF}.supabase.co:"*)
    database="$METRA_COMPARE_SOURCE_DB"
    ;;
  *"@db.${METRA_DST_PROJECT_REF}.supabase.co:"*)
    database="$METRA_COMPARE_TARGET_DB"
    ;;
  *)
    echo "Refusing: comparison test blocked a non-fixture connection URL." >&2
    exit 92
    ;;
esac
exec "$METRA_COMPARE_REAL_PSQL" -d "$database" "$@"
WRAPPER
chmod 700 "$WORK_DIR/bin/psql"
export PATH="$WORK_DIR/bin:$PATH"

run_compare_pass() {
  local label="$1"
  local output="$WORK_DIR/$label-output"
  local log="$WORK_DIR/$label.log"
  if ! METRA_TRANSFER_OUT="$output" bash "$RUNNER" >"$log" 2>&1; then
    echo "FAIL: identical synthetic databases did not compare successfully ($label)." >&2
    cat "$log" >&2
    exit 1
  fi
  grep -Fq 'PASS: exact row counts and SHA-256 table-content fingerprints' "$log" || {
    echo "FAIL: comparison did not emit its acceptance PASS marker ($label)." >&2
    cat "$log" >&2
    exit 1
  }
}

expect_compare_failure() {
  local label="$1"
  local marker="${2:-FAIL: differences detected}"
  local output="$WORK_DIR/$label-output"
  local log="$WORK_DIR/$label.log"
  if METRA_TRANSFER_OUT="$output" bash "$RUNNER" >"$log" 2>&1; then
    echo "FAIL: comparison accepted deliberate target drift ($label)." >&2
    cat "$log" >&2
    exit 1
  fi
  grep -Fq "$marker" "$log" || {
    echo "FAIL: comparison failed for an unexpected reason ($label)." >&2
    cat "$log" >&2
    exit 1
  }
}

target_sql() {
  "$REAL_PSQL" -X -v ON_ERROR_STOP=1 -d "$TARGET_DB" -c "$1" >/dev/null
}

# Baseline: all data, object, sequence, ACL, extension and provenance inventories match.
run_compare_pass "baseline"

# Exact row counts must detect added application rows.
target_sql "INSERT INTO public.auth_fk_fixture(id,user_id,note) VALUES (2,'22222222-2222-4222-8222-222222222222','extra-row')"
expect_compare_failure "row-count-drift"
target_sql "DELETE FROM public.auth_fk_fixture WHERE id=2"

# Content fingerprints must detect same-cardinality payload edits.
target_sql "UPDATE public.auth_fk_fixture SET note='tampered-payload' WHERE id=1"
expect_compare_failure "content-hash-drift"
target_sql "UPDATE public.auth_fk_fixture SET note='fixture' WHERE id=1"

# Auth FK cardinality is checked independently from content hashing.
target_sql "UPDATE public.auth_fk_fixture SET user_id=NULL WHERE id=1"
expect_compare_failure "auth-fk-cardinality-drift"
target_sql "UPDATE public.auth_fk_fixture SET user_id='11111111-1111-4111-8111-111111111111' WHERE id=1"

# Sequence last_value is part of the restore acceptance contract.
target_sql "SELECT setval('public.station_audit_log_id_seq',99,true)"
expect_compare_failure "sequence-state-drift"
target_sql "SELECT setval('public.station_audit_log_id_seq',42,true)"

# Structural inventories include views and must reject target-only objects.
target_sql "CREATE VIEW public.compare_fixture_unexpected AS SELECT 1 AS value"
expect_compare_failure "object-inventory-drift"
target_sql "DROP VIEW public.compare_fixture_unexpected"

# Reviewed existing object grants are compared separately from tightened defaults.
target_sql "REVOKE SELECT ON TABLE public.countries FROM service_role"
expect_compare_failure "acl-drift"
target_sql "GRANT ALL PRIVILEGES ON TABLE public.countries TO service_role"

# Station approval/provenance differences must be visible even when row counts match.
target_sql "UPDATE public.station_catalogue SET approval_status='approved' WHERE id='00000000-0000-4000-8000-000000000001'"
expect_compare_failure "station-provenance-drift"
target_sql "UPDATE public.station_catalogue SET approval_status='pending' WHERE id='00000000-0000-4000-8000-000000000001'"

# The excluded observation-history table is checked independently and must stay empty.
target_sql "INSERT INTO public.metra_observation_records(id) VALUES ('00000000-0000-4000-8000-000000000901')"
expect_compare_failure "excluded-observation-data-drift"
target_sql "DELETE FROM public.metra_observation_records"

# Missing the required digest extension must fail closed before acceptance.
target_sql "DROP EXTENSION pgcrypto"
expect_compare_failure "missing-hash-extension" "function extensions.digest"
target_sql "CREATE EXTENSION pgcrypto WITH SCHEMA extensions"

# Final clean comparison proves every mutation was rolled back to the accepted fixture.
run_compare_pass "final-clean"

echo "PASS: full source/target comparison integration suite passed on isolated synthetic PostgreSQL databases."
echo "PASS: baseline, row counts, content hashes, Auth FK cardinality, sequences, objects, ACLs, station provenance, excluded history, and missing digest extension were exercised."
