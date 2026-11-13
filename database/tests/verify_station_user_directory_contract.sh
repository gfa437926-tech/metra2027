#!/usr/bin/env bash
set -euo pipefail
migration="database/migrations/010_station_user_directory_read_model.sql"
permission_migration="database/migrations/011_station_user_directory_permission.sql"
proposal="database/proposals/033_atomic_actor_station_read_rpcs.sql"
endpoint="backend/Metra.Api/Features/Users/StationUserDirectoryEndpoints.cs"
program="backend/Metra.Api/Program.cs"
grep -Fq "LEFT JOIN public.metra_account_states AS state" "$migration"
grep -Fq "JOIN public.metra_user_profiles AS p" "$migration"
grep -Fq "REVOKE ALL" "$migration"
grep -Fq "TO service_role" "$migration"
grep -Fq "('station_head', 'users.station.view')" "$permission_migration"
grep -Fq "('system_admin', 'users.station.view')" "$permission_migration"
grep -Fq "get_station_user_directory_atomic" "$proposal"
grep -Fq "metra_lock_authorized_station_read" "$proposal"
grep -Fq "rpc/get_station_user_directory_atomic" "$endpoint"
grep -Fq 'FindFirstValue("sub")' "$endpoint"
if grep -Fq '.RequireStationPermission("users.station.view")' "$endpoint"; then
  echo "Split API-side station authorization must not guard an atomic read endpoint" >&2; exit 1
fi
grep -Fq 'app.MapStationUserDirectoryEndpoints();' "$program"
grep -Fq 'IStationUserDirectoryService, SupabaseStationUserDirectoryService' "$program"
echo "Station user directory actor-bound atomic authorization contract verified."
