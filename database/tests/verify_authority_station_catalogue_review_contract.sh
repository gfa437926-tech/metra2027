#!/usr/bin/env bash
set -euo pipefail

migration="database/migrations/016_authority_scoped_station_catalogue_review.sql"
endpoint="backend/Metra.Api/Features/Stations/StationCatalogueReviewEndpoints.cs"
service="backend/Metra.Api/Security/StationAuthorizationService.cs"

grep -Fq "metra_user_has_station_owner_authority_permission" "$migration"
grep -Fq "membership.authority_id = v_authority_id" "$migration"
grep -Fq "role_permission.permission_code = 'stations.catalogue.review'" "$migration"
grep -Fq "permission.revoked_at IS NULL" "$migration"
grep -Fq "FOR SHARE OF membership, role, role_permission" "$migration"
grep -Fq "FOR SHARE" "$migration"
grep -Fq "private.decide_station_catalogue_review" "$migration"
grep -Fq "FROM PUBLIC, anon, authenticated" "$migration"
grep -Fq "TO service_role" "$migration"
grep -Fq '.RequireStationOwnerAuthorityPermission("stations.catalogue.review")' "$endpoint"
grep -Fq 'metra_user_has_station_owner_authority_permission' "$service"

echo "Authority-scoped station catalogue review contract verified."
