-- C2.5 APPLY candidate — active grant uniqueness (partial indexes)
-- DO NOT run on hosted without explicit approval and empty precheck duplicate queries.
-- Does not delete or rewrite grant/audit history.

CREATE UNIQUE INDEX IF NOT EXISTS permission_grants_active_station_unique
ON public.permission_grants (user_id, station_id, permission_code)
WHERE approval_status = 'approved'
  AND revoked_at IS NULL
  AND station_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS permission_grants_active_authority_unique
ON public.permission_grants (user_id, authority_id, permission_code)
WHERE approval_status = 'approved'
  AND revoked_at IS NULL
  AND station_id IS NULL;
