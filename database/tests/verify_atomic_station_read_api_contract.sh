#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
queue="$ROOT/backend/Metra.Api/Features/Observations/ObservationQueueEndpoints.cs"
users="$ROOT/backend/Metra.Api/Features/Users/StationUserDirectoryEndpoints.cs"
audit="$ROOT/backend/Metra.Api/Features/Users/StationAuditEndpoints.cs"
archive="$ROOT/backend/Metra.Api/Features/Observations/ObservationArchiveEndpoints.cs"
proposal="$ROOT/database/proposals/033_atomic_actor_station_read_rpcs.sql"
program="$ROOT/backend/Metra.Api/Program.cs"
for file in "$queue" "$users" "$audit" "$archive"; do
  grep -q 'FindFirstValue("sub")' "$file"
  grep -q 'p_actor_user_id' "$file"
done
grep -q 'get_station_observation_review_queue_atomic' "$queue"
grep -q 'get_station_user_directory_atomic' "$users"
grep -q 'get_station_audit_log_atomic' "$audit"
grep -q 'get_station_observation_archive_atomic' "$archive"
grep -q 'get_station_observation_archive_item_atomic' "$archive"
grep -q 'private.metra_lock_authorized_station_read' "$proposal"
grep -q 'o.station_id = p_station_id' "$proposal"
grep -q 'o.is_demo = false' "$proposal"
grep -q "'raw_data'" "$proposal"
grep -q 'TO service_role' "$proposal"
if grep -q 'HasStationPermissionAsync' "$queue" "$archive"; then
  echo "FAIL: sensitive read endpoint retains split API-side authorization" >&2; exit 1
fi
if grep -q 'HasStationArchivePermissionAsync' "$archive"; then
  echo "FAIL: archive endpoint must use its actor-bound read RPC, not a separate pre-check" >&2; exit 1
fi
if grep -q 'RequireStationPermission' "$users" "$audit"; then
  echo "FAIL: station directory/audit retain split API-side authorization" >&2; exit 1
fi
grep -q 'IObservationArchiveService, SupabaseObservationArchiveService' "$program"
echo "PASS: directory, audit, queue and archive reads use actor-bound atomic RPCs"
