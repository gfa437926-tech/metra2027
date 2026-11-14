#!/usr/bin/env bash
set -euo pipefail
migration="database/migrations/014_station_audit_read_model.sql"
proposal="database/proposals/033_atomic_actor_station_read_rpcs.sql"
endpoint="backend/Metra.Api/Features/Users/StationAuditEndpoints.cs"
program="backend/Metra.Api/Program.cs"
grep -Fq "get_station_audit_log" "$migration"
grep -Fq "entity_type = 'station_assignment'" "$migration"
grep -Fq "entity_type = 'station'" "$migration"
grep -Fq "p_limit > 250" "$migration"
grep -Fq "REVOKE ALL" "$migration"
grep -Fq "FROM anon, authenticated" "$migration"
grep -Fq "TO service_role" "$migration"
grep -Fq "get_station_audit_log_atomic" "$proposal"
grep -Fq "metra_lock_authorized_station_read" "$proposal"
grep -Fq "rpc/get_station_audit_log_atomic" "$endpoint"
grep -Fq 'FindFirstValue("sub")' "$endpoint"
if grep -Fq '.RequireStationPermission("users.station.view")' "$endpoint"; then
  echo "Split API-side station authorization must not guard an atomic read endpoint" >&2; exit 1
fi
grep -Fq "app.MapStationAuditEndpoints();" "$program"
grep -Fq "IStationAuditService, SupabaseStationAuditService" "$program"
echo "Station audit actor-bound atomic authorization contract verified."
