#!/usr/bin/env bash
set -euo pipefail

migration="database/migrations/009_secure_registration_submission_and_status.sql"
endpoint="backend/Metra.Api/Features/Users/RegistrationSubmissionEndpoints.cs"
program="backend/Metra.Api/Program.cs"

grep -Fq "s.approval_status = 'approved'" "$migration"
grep -Fq "s.operational_status = 'active'" "$migration"
grep -Fq "s.is_demo = false" "$migration"
grep -Fq "public.submit_metra_registration(" "$migration"
grep -Fq "public.get_metra_registration_status" "$migration"
grep -Fq "REVOKE ALL ON FUNCTION public.submit_metra_registration_for_active_station" "$migration"
grep -Fq "REVOKE ALL ON FUNCTION public.get_metra_registration_status" "$migration"
grep -Fq "TO service_role" "$migration"
grep -Fq 'http.User.FindFirstValue("sub")' "$endpoint"
grep -Fq "submit_metra_registration_for_active_station" "$endpoint"
grep -Fq "GetRequestableRolesAsync" "$endpoint"
grep -Fq "RegistrationSubmissionRequestGuard.GetError" "$endpoint"
grep -Fq "app.MapRegistrationSubmissionEndpoints();" "$program"
grep -Fq "IRegistrationSubmissionService, SupabaseRegistrationSubmissionService" "$program"

echo "Authenticated registration submission and own-status contract verified."
