#!/usr/bin/env bash
set -euo pipefail

migration="database/migrations/006_station_bound_registration_decision.sql"
permission_migration="database/migrations/007_system_registration_review_permission.sql"
endpoint="backend/Metra.Api/Features/Users/RegistrationReviewEndpoints.cs"
program="backend/Metra.Api/Program.cs"

grep -Fq "FOR UPDATE" "$migration"
grep -Fq "v_requested_station_id IS DISTINCT FROM p_station_id" "$migration"
grep -Fq "REVOKE ALL" "$migration"
grep -Fq "TO service_role" "$migration"
grep -Fq "('system_admin', 'registrations.system.approve')" "$permission_migration"
grep -Fq "decide_metra_registration_for_station" "$endpoint"
grep -Fq "p_station_id = stationId" "$endpoint"
grep -Fq 'p_expected_status = expectedStatus' "$endpoint"
grep -Fq '"pending_system_approval"' "$endpoint"
grep -Fq 'RegistrationDecisionRpcResult.GetStatus(outcome.Data)' "$endpoint"
grep -Fq '.RequireStationPermission("registrations.station.approve")' "$endpoint"
grep -Fq '.RequireStationPermission("registrations.system.approve")' "$endpoint"
grep -Fq 'app.MapRegistrationReviewEndpoints();' "$program"
grep -Fq 'IRegistrationReviewService, SupabaseRegistrationReviewService' "$program"

echo "Station-bound, two-stage registration review contract verified."
