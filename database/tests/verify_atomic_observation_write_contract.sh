#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
proposal="$ROOT/database/proposals/034_atomic_observation_write_authorization.sql"
helper="$ROOT/database/proposals/033_atomic_actor_station_read_rpcs.sql"
api="$ROOT/backend/Metra.Api/Features/Observations/ObservationSubmissionEndpoints.cs"
grep -q "private.metra_lock_authorized_station_read(p_user_id,p_station_id,'observation.create')" "$proposal"
grep -q "private.metra_lock_authorized_station_read(p_user_id,p_station_id,'observation.submit')" "$proposal"
grep -q "private.metra_lock_authorized_station_read(p_user_id,p_station_id,v_permission)" "$proposal"
grep -q "'observation.create'" "$helper"
grep -q "'observation.submit'" "$helper"
grep -q "'observation.approve'" "$helper"
grep -q "'observation.return_for_correction'" "$helper"
grep -q 'FindFirstValue("sub")' "$api"
if grep -q 'RequireStationPermission' "$api" || grep -q 'HasStationPermissionAsync' "$api"; then
  echo "FAIL: observation writes retain split API-side authorization" >&2; exit 1
fi
grep -q 'MapDatabaseErrorStatusAsync' "$api"
echo "PASS: submit and decision RPCs lock actor authorization in the write transaction"
