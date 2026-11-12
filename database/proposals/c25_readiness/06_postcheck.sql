-- C2.5 post-apply verification queries

-- Function still returns boolean, same name/args
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS result
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname='public' AND p.proname='metra_user_has_station_permission';

-- Archive bind present in definition
SELECT position('observation.archive.read' IN pg_get_functiondef('public.metra_user_has_station_permission(uuid,uuid,text)'::regprocedure)) > 0
  AS archive_predicate_present;

-- Indexes exist
SELECT indexname FROM pg_indexes
WHERE tablename='permission_grants'
  AND indexname IN ('permission_grants_active_station_unique','permission_grants_active_authority_unique')
ORDER BY 1;

-- No duplicate actives
SELECT count(*) AS dup_station_groups FROM (
  SELECT 1 FROM permission_grants
  WHERE approval_status='approved' AND revoked_at IS NULL AND station_id IS NOT NULL
  GROUP BY user_id, station_id, permission_code HAVING count(*)>1
) s;

SELECT count(*) AS dup_authority_groups FROM (
  SELECT 1 FROM permission_grants
  WHERE approval_status='approved' AND revoked_at IS NULL AND station_id IS NULL
  GROUP BY user_id, authority_id, permission_code HAVING count(*)>1
) s;
