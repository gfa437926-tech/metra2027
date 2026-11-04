#!/usr/bin/env bash
set -euo pipefail

migration="database/migrations/004_station_catalogue_review_permission.sql"
endpoint="backend/Metra.Api/Features/Stations/StationCatalogueReviewEndpoints.cs"

grep -Fq "('network_director', 'stations.catalogue.review')" "$migration"
grep -Fq "ON CONFLICT (role_code, permission_code) DO NOTHING" "$migration"
grep -Fq '.RequireStationPermission("stations.catalogue.review")' "$endpoint"
grep -Fq 'request.ExpectedStatus != "pending"' "$endpoint"
grep -Fq 'request.Decision is not ("approved" or "rejected" or "changes_requested")' "$endpoint"
grep -Fq 'p_actor_user_id = actorUserId' "$endpoint"
grep -Fq 'decide_station_catalogue_review' "$endpoint"

echo "Station catalogue review authorization contract verified."
