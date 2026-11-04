#!/usr/bin/env bash
set -euo pipefail

sql_file="database/migrations/015_authority_scoped_permission_rpc.sql"
test -f "$sql_file"

require_sql() {
  local fragment="$1"
  if ! grep -Fq "$fragment" "$sql_file"; then
    echo "Missing required authority authorization SQL contract: $fragment" >&2
    exit 1
  fi
}

require_sql "CREATE OR REPLACE FUNCTION public.metra_user_has_authority_permission("
require_sql "JOIN public.authority_memberships AS membership"
require_sql "membership.authority_id = authority.id"
require_sql "JOIN public.metra_role_permissions AS role_permission"
require_sql "role_permission.permission_code = p_permission_code"
require_sql "JOIN public.permission_grants AS permission"
require_sql "account.account_state = 'active'"
require_sql "authority.is_active = TRUE"
require_sql "country.is_active = TRUE"
require_sql "membership.approval_status = 'approved'"
require_sql "permission.approval_status = 'approved'"
require_sql "permission.revoked_at IS NULL"
require_sql "REVOKE ALL ON FUNCTION public.metra_user_has_authority_permission(uuid, uuid, text)"
require_sql "FROM PUBLIC, anon, authenticated"
require_sql "GRANT EXECUTE ON FUNCTION public.metra_user_has_authority_permission(uuid, uuid, text)"
require_sql "TO service_role"

if grep -Eiq "GRANT EXECUTE ON FUNCTION public\\.metra_user_has_authority_permission.* TO (anon|authenticated)" "$sql_file"; then
  echo "Authority authorization RPC must not be executable by public client roles." >&2
  exit 1
fi

echo "Authority authorization SQL contract verified."
