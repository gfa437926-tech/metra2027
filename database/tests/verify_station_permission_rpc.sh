#!/usr/bin/env bash
set -euo pipefail

sql_file="database/migrations/003_station_permission_rpc.sql"
test -f "$sql_file"

require_sql() {
  local fragment="$1"
  if ! grep -Fq "$fragment" "$sql_file"; then
    echo "Missing required station authorization SQL contract: $fragment" >&2
    exit 1
  fi
}

require_sql "JOIN public.metra_role_permissions AS role_permission"
require_sql "role_permission.permission_code = p_permission_code"
require_sql "JOIN public.permission_grants AS permission"
require_sql "account.account_state = 'active'"
require_sql "assignment.approval_status = 'approved'"
require_sql "permission.revoked_at IS NULL"
require_sql "REVOKE ALL ON FUNCTION public.metra_user_has_station_permission(uuid, uuid, text) FROM PUBLIC"
require_sql "GRANT EXECUTE ON FUNCTION public.metra_user_has_station_permission(uuid, uuid, text) TO service_role"

if grep -Eiq "GRANT EXECUTE ON FUNCTION public\\.metra_user_has_station_permission.* TO (anon|authenticated)" "$sql_file"; then
  echo "Station authorization RPC must not be executable by public client roles." >&2
  exit 1
fi

echo "Station authorization SQL contract verified."

# Observation decision contracts (always) and isolated PostgreSQL tests when a server is reachable.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$ROOT/database/tests/verify_observation_decision_contract.sh"
run_pg_tests() {
  bash "$ROOT/database/tests/run_observation_decision_isolated_pg_tests.sh"
}
if command -v psql >/dev/null 2>&1; then
  if psql -d postgres -c "select 1" >/dev/null 2>&1; then
    run_pg_tests
  elif [[ -n "${PGPASSWORD:-}" ]] && PGPASSWORD="$PGPASSWORD" psql -h "${PGHOST:-localhost}" -U "${PGUSER:-postgres}" -d postgres -c "select 1" >/dev/null 2>&1; then
    run_pg_tests
  elif command -v su >/dev/null 2>&1 && su - postgres -c "psql -d postgres -c 'select 1'" >/dev/null 2>&1; then
    su - postgres -c "cd '$ROOT' && bash database/tests/run_observation_decision_isolated_pg_tests.sh"
  else
    echo "Observation decision SQL contract verified; isolated PG tests not executed (no reachable PostgreSQL in this job)."
  fi
else
  echo "Observation decision SQL contract verified; isolated PG tests not executed (psql not installed in this job)."
fi

