#!/usr/bin/env bash
set -euo pipefail

sql_file="supabase/migrations/20261107020000_harden_observation_decision_sod_and_audit.sql"
test -f "$sql_file"

require() {
  local fragment="$1"
  if ! grep -Fq "$fragment" "$sql_file"; then
    echo "Missing observation decision SQL contract: $fragment" >&2
    exit 1
  fi
}

require "self_review_forbidden"
require "for update"
require "observation_not_in_submitted_state"
require "station_observation_decision_forbidden"
require "metra_user_has_station_permission"
require "metra_observation_audit_events"
require "v_event_type := v_status"
require "grant execute on function public.metra_decide_observation"
require "from public, anon, authenticated, metra_api_runtime"

if grep -Eiq "grant execute on function public\\.metra_decide_observation.* to (anon|authenticated)" "$sql_file"; then
  echo "Observation decision RPC must not be executable by public client roles." >&2
  exit 1
fi

echo "Observation decision SQL contract verified."
