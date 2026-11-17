-- C2.5 pre-apply checks (read-only intent). Safe on any clone; do not write hosted.
-- 1) Function signature exists
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'metra_user_has_station_permission';

-- 2) Duplicate active station-scoped grants (must be empty before unique index)
SELECT user_id, station_id, permission_code, count(*) AS active_cnt
FROM public.permission_grants
WHERE approval_status = 'approved'
  AND revoked_at IS NULL
  AND station_id IS NOT NULL
GROUP BY 1,2,3
HAVING count(*) > 1;

-- 3) Duplicate active authority-scoped grants (station_id IS NULL)
SELECT user_id, authority_id, permission_code, count(*) AS active_cnt
FROM public.permission_grants
WHERE approval_status = 'approved'
  AND revoked_at IS NULL
  AND station_id IS NULL
GROUP BY 1,2,3
HAVING count(*) > 1;

-- 4) Archive grants missing station_id (should be zero if CHECK already present)
SELECT count(*) AS archive_grants_missing_station
FROM public.permission_grants
WHERE permission_code = 'observation.archive.read'
  AND station_id IS NULL;
