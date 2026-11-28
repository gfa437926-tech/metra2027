#!/usr/bin/env bash
set -euo pipefail

migration="database/migrations/005_station_registration_review_permission.sql"
endpoint="backend/Metra.Api/Features/Users/RegistrationReviewEndpoints.cs"

grep -Fq "('station_head', 'registrations.station.approve')" "$migration"
grep -Fq "ON CONFLICT (role_code, permission_code) DO NOTHING" "$migration"
grep -Fq '.RequireStationPermission("registrations.station.approve")' "$endpoint"
grep -Fq 'p_expected_status = "pending_station_approval"' "$endpoint"
grep -Fq 'p_actor_user_id = actorUserId' "$endpoint"
grep -Fq 'decide_metra_registration' "$endpoint"
grep -Fq 'request.Decision is not ("approve" or "reject")' "$endpoint"
grep -Fq 'registration_rejection_reason_required' "$endpoint"

echo "Station registration review authorization contract verified."
