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
