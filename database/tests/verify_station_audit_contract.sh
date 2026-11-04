#!/usr/bin/env bash
set -euo pipefail

migration="database/migrations/014_station_audit_read_model.sql"
endpoint="backend/Metra.Api/Features/Users/StationAuditEndpoints.cs"
program="backend/Metra.Api/Program.cs"

grep -Fq "get_station_audit_log" "$migration"
grep -Fq "entity_type = 'station_assignment'" "$migration"
grep -Fq "entity_type = 'station'" "$migration"
grep -Fq "p_limit > 250" "$migration"
grep -Fq "REVOKE ALL" "$migration"
grep -Fq "FROM anon, authenticated" "$migration"
grep -Fq "TO service_role" "$migration"
grep -Fq "get_station_audit_log" "$endpoint"
grep -Fq '.RequireStationPermission("users.station.view")' "$endpoint"
grep -Fq "app.MapStationAuditEndpoints();" "$program"
grep -Fq "IStationAuditService, SupabaseStationAuditService" "$program"

echo "Station audit read-model authorization contract verified."
