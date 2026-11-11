#!/usr/bin/env bash
set -euo pipefail

decide_sql="supabase/migrations/20261107020000_harden_observation_decision_sod_and_audit.sql"
resubmit_sql="supabase/migrations/20261107021500_observation_resubmit_after_return.sql"
test -f "$decide_sql"
test -f "$resubmit_sql"

require() {
  local file="$1"
  local fragment="$2"
  if ! grep -Fq "$fragment" "$file"; then
    echo "Missing SQL contract in ${file}: ${fragment}" >&2
    exit 1
  fi
}

require "$decide_sql" "self_review_forbidden"
require "$decide_sql" "for update"
require "$decide_sql" "observation_not_in_submitted_state"
require "$decide_sql" "station_observation_decision_forbidden"
require "$decide_sql" "metra_user_has_station_permission"
require "$decide_sql" "metra_observation_audit_events"
require "$decide_sql" "v_event_type := v_status"
require "$decide_sql" "grant execute on function public.metra_decide_observation"

require "$resubmit_sql" "metra_resubmit_observation"
require "$resubmit_sql" "observation_not_in_returned_state"
require "$resubmit_sql" "not_observation_owner"
require "$resubmit_sql" "resubmitted"
require "$resubmit_sql" "grant execute on function public.metra_resubmit_observation"

if grep -Eiq "grant execute on function public\\.metra_decide_observation.* to (anon|authenticated)" "$decide_sql"; then
  echo "Observation decision RPC must not be executable by public client roles." >&2
  exit 1
fi
if grep -Eiq "grant execute on function public\\.metra_resubmit_observation.* to (anon|authenticated)" "$resubmit_sql"; then
  echo "Observation resubmit RPC must not be executable by public client roles." >&2
  exit 1
fi

# Production audit immutability trigger must exist in the observation foundation migration.
foundation="supabase/migrations/20261103164003_create_operational_observation_submission.sql"
test -f "$foundation"
require "$foundation" "metra_observation_audit_immutable"
require "$foundation" "reject_metra_observation_audit_mutation"

echo "Observation decision SQL contract verified."
