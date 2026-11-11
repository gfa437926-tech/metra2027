#!/usr/bin/env bash
set -euo pipefail

session="backend/Metra.Api/Infrastructure/Persistence/NpgsqlOpsSession.cs"
fault_service="backend/Metra.Api/Infrastructure/Persistence/NpgsqlEquipmentFaultService.cs"
support_service="backend/Metra.Api/Infrastructure/Persistence/NpgsqlSupportIncidentService.cs"
rls="supabase/migrations/20261108020000_npgsql_ops_session_context_rls.sql"
rpc="supabase/migrations/20261107032000_harden_ops_rls_and_assignee_checks.sql"
pg_test="database/tests/ops_station_isolation_pg_test.sql"

require_in() {
  local file="$1"
  local fragment="$2"
  if ! grep -Fq "$fragment" "$file"; then
    echo "Missing station-isolation security invariant in $file: $fragment" >&2
    exit 1
  fi
}

# Npgsql must bind the constrained role and identity/station context transaction-locally.
require_in "$session" 'set local role {OpsRole}'
require_in "$session" "set_config('app.user_id', @user_id, true)"
require_in "$session" "set_config('app.station_id', @station_id, true)"
require_in "$session" 'BeginTransactionAsync'

# Role membership and RLS must be forced for every ops data/audit table.
require_in "$rls" 'create role metra_ops_faults nologin'
require_in "$rls" 'grant metra_ops_faults to metra_api_runtime'
for table in metra_equipment_faults metra_equipment_fault_audit_events metra_support_incidents metra_support_incident_audit_events; do
  require_in "$rls" "alter table if exists public.$table force row level security"
  require_in "$rls" "create policy"
done
require_in "$rls" "station_id = nullif(current_setting('app.station_id', true), '')::uuid"

# Each Npgsql list/detail/transition query must keep an explicit station predicate.
for service in "$fault_service" "$support_service"; do
  require_in "$service" 'where station_id = @station_id'
  require_in "$service" 'where id = @id and station_id = @station_id'
  require_in "$service" 'BeginScopedAsync'
done

# Security-definer transitions must validate permission and station ownership.
require_in "$rpc" 'security definer'
require_in "$rpc" 'set search_path = pg_catalog, public'
require_in "$rpc" 'metra_user_has_station_permission(p_user_id, p_station_id, v_permission)'
require_in "$rpc" 'equipment_fault_station_mismatch'
require_in "$rpc" 'support_incident_station_mismatch'
require_in "$rpc" 'revoke all on function public.metra_transition_equipment_fault'
require_in "$rpc" 'revoke all on function public.metra_transition_support_incident'

# Live PostgreSQL harness is restricted to a disposable empty DB and rolls back fixtures.
require_in "$pg_test" "current_database() <> 'metra_ops_test'"
require_in "$pg_test" "IF current_setting('transaction_read_only') = 'on'"
require_in "$pg_test" 'BEGIN;'
require_in "$pg_test" 'ROLLBACK;'

echo "Station isolation static security contract verified."
