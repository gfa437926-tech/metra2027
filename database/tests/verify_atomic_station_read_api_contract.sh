#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
queue="$ROOT/backend/Metra.Api/Features/Observations/ObservationQueueEndpoints.cs"
users="$ROOT/backend/Metra.Api/Features/Users/StationUserDirectoryEndpoints.cs"
audit="$ROOT/backend/Metra.Api/Features/Users/StationAuditEndpoints.cs"
for file in "$queue" "$users" "$audit"; do
  grep -q 'FindFirstValue("sub")' "$file"
  grep -q 'p_actor_user_id' "$file"
done
grep -q 'get_station_observation_review_queue_atomic' "$queue"
grep -q 'get_station_user_directory_atomic' "$users"
grep -q 'get_station_audit_log_atomic' "$audit"
if grep -q 'HasStationPermissionAsync' "$queue"; then
  echo "FAIL: observation queue retains split API-side authorization" >&2; exit 1
fi
if grep -q 'RequireStationPermission' "$users" "$audit"; then
  echo "FAIL: station directory/audit retain split API-side authorization" >&2; exit 1
fi
echo "PASS: sensitive station reads pass validated JWT subject to actor-bound atomic RPCs"
