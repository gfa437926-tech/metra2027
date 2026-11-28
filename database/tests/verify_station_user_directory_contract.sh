#!/usr/bin/env bash
set -euo pipefail

migration="database/migrations/010_station_user_directory_read_model.sql"
permission_migration="database/migrations/011_station_user_directory_permission.sql"
endpoint="backend/Metra.Api/Features/Users/StationUserDirectoryEndpoints.cs"
program="backend/Metra.Api/Program.cs"

grep -Fq "LEFT JOIN public.metra_account_states AS state" "$migration"
grep -Fq "JOIN public.metra_user_profiles AS p" "$migration"
grep -Fq "REVOKE ALL" "$migration"
grep -Fq "TO service_role" "$migration"
grep -Fq "('station_head', 'users.station.view')" "$permission_migration"
grep -Fq "('system_admin', 'users.station.view')" "$permission_migration"
grep -Fq "rpc/get_station_user_directory" "$endpoint"
grep -Fq '.RequireStationPermission("users.station.view")' "$endpoint"
grep -Fq 'app.MapStationUserDirectoryEndpoints();' "$program"
grep -Fq 'IStationUserDirectoryService, SupabaseStationUserDirectoryService' "$program"

echo "Station user directory authorization contract verified."
