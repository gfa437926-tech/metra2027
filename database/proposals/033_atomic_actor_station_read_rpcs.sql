-- PROPOSAL ONLY — C9.4 atomic actor-bound station read RPCs.
-- DO NOT APPLY TO HOSTED SUPABASE without explicit owner approval.
-- Execute only in the isolated PostgreSQL test environment.
-- API derives p_actor_user_id exclusively from the validated JWT sub claim.
-- These RPCs are service_role-only; the key must remain server-side.
-- Authorization rows are locked FOR SHARE before the protected projection is read.

CREATE SCHEMA IF NOT EXISTS private;
GRANT USAGE ON SCHEMA private TO service_role;

CREATE OR REPLACE FUNCTION private.metra_lock_authorized_station_read(
  p_actor_user_id uuid, p_station_id uuid, p_permission_code text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $function$
DECLARE v_now timestamptz := clock_timestamp();
BEGIN
  IF p_actor_user_id IS NULL OR p_actor_user_id = '00000000-0000-0000-0000-000000000000'::uuid
     OR p_station_id IS NULL OR p_station_id = '00000000-0000-0000-0000-000000000000'::uuid
     OR p_permission_code IS NULL OR p_permission_code NOT IN ('users.station.view','observation.review','observation.archive.read') THEN
    RETURN false;
  END IF;

  IF p_permission_code = 'observation.archive.read' THEN
    PERFORM 1
    FROM public.metra_account_states ac
    JOIN public.station_catalogue s ON s.id = p_station_id
    JOIN public.meteorological_authorities a ON a.id = s.owner_authority_id AND a.country_id = s.country_id
    JOIN public.countries c ON c.id = s.country_id
    JOIN public.authority_memberships m ON m.user_id = ac.user_id AND m.authority_id = s.owner_authority_id
    JOIN public.station_assignments sa ON sa.user_id = ac.user_id AND sa.station_id = s.id AND sa.authority_id = s.owner_authority_id
    JOIN public.metra_role_catalogue r ON r.role_code = sa.assignment_role_code
    JOIN public.permission_grants g ON g.user_id = ac.user_id AND g.authority_id = s.owner_authority_id
    WHERE ac.user_id = p_actor_user_id AND ac.account_state = 'active'
      AND s.approval_status = 'approved' AND s.operational_status = 'active' AND s.is_demo = false
      AND a.is_active AND c.is_active
      AND m.approval_status = 'approved' AND m.revoked_at IS NULL
      AND m.valid_from <= v_now AND (m.valid_to IS NULL OR m.valid_to > v_now)
      AND sa.approval_status = 'approved'
      AND sa.valid_from <= v_now AND (sa.valid_to IS NULL OR sa.valid_to > v_now)
      AND r.is_active
      AND g.permission_code = p_permission_code AND g.approval_status = 'approved'
      AND g.approved_by IS NOT NULL AND g.reviewed_at IS NOT NULL AND g.revoked_at IS NULL
      AND g.valid_from <= v_now AND (g.valid_to IS NULL OR g.valid_to > v_now)
    ORDER BY ac.user_id, s.id, a.id, c.id, m.id, sa.id, r.role_code, g.id
    FOR SHARE OF ac, s, a, c, m, sa, r, g;
  ELSE
    PERFORM 1
    FROM public.metra_account_states ac
    JOIN public.station_catalogue s ON s.id = p_station_id
    JOIN public.meteorological_authorities a ON a.id = s.owner_authority_id AND a.country_id = s.country_id
    JOIN public.countries c ON c.id = s.country_id
    JOIN public.authority_memberships m ON m.user_id = ac.user_id AND m.authority_id = s.owner_authority_id
    JOIN public.station_assignments sa ON sa.user_id = ac.user_id AND sa.station_id = s.id AND sa.authority_id = s.owner_authority_id
    JOIN public.metra_role_catalogue r ON r.role_code = sa.assignment_role_code
    JOIN public.metra_role_permissions rp ON rp.role_code = r.role_code AND rp.permission_code = p_permission_code
    JOIN public.permission_grants g ON g.user_id = ac.user_id AND g.authority_id = s.owner_authority_id
    WHERE ac.user_id = p_actor_user_id AND ac.account_state = 'active'
      AND s.approval_status = 'approved' AND s.operational_status = 'active' AND s.is_demo = false
      AND a.is_active AND c.is_active
      AND m.approval_status = 'approved' AND m.revoked_at IS NULL
      AND m.valid_from <= v_now AND (m.valid_to IS NULL OR m.valid_to > v_now)
      AND sa.approval_status = 'approved'
      AND sa.valid_from <= v_now AND (sa.valid_to IS NULL OR sa.valid_to > v_now)
      AND r.is_active
      AND g.permission_code = p_permission_code AND g.approval_status = 'approved'
      AND g.approved_by IS NOT NULL AND g.reviewed_at IS NOT NULL AND g.revoked_at IS NULL
      AND g.valid_from <= v_now AND (g.valid_to IS NULL OR g.valid_to > v_now)
    ORDER BY ac.user_id, s.id, a.id, c.id, m.id, sa.id, r.role_code, rp.permission_code, g.id
    FOR SHARE OF ac, s, a, c, m, sa, r, rp, g;
  END IF;

  RETURN FOUND;
END;
$function$;

REVOKE ALL ON FUNCTION private.metra_lock_authorized_station_read(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.metra_lock_authorized_station_read(uuid, uuid, text) TO service_role;

CREATE OR REPLACE FUNCTION public.get_station_user_directory_atomic(
  p_actor_user_id uuid, p_station_id uuid, p_limit integer DEFAULT 250
)
RETURNS SETOF jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog, public AS $function$
BEGIN
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'invalid_station_user_directory_query' USING ERRCODE = '22023';
  END IF;
  IF NOT private.metra_lock_authorized_station_read(p_actor_user_id,p_station_id,'users.station.view') THEN
    RAISE EXCEPTION 'station_user_directory_forbidden' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY SELECT jsonb_build_object(
    'user_id',p.user_id,'first_name',p.first_name,'father_name',p.father_name,'last_name',p.last_name,
    'phone',p.phone,'account_state',state.account_state,'state_reason',state.state_reason,
    'assignment_id',assignment.id,'assignment_role_code',assignment.assignment_role_code,
    'assignment_status',assignment.approval_status,'valid_from',assignment.valid_from,
    'valid_to',assignment.valid_to,'station_id',assignment.station_id,
    'role_name_ar',role.name_ar,'role_name_en',role.name_en)
  FROM public.station_assignments assignment
  JOIN public.metra_user_profiles p ON p.user_id=assignment.user_id
  LEFT JOIN public.metra_account_states state ON state.user_id=assignment.user_id
  LEFT JOIN public.metra_role_catalogue role ON role.role_code=assignment.assignment_role_code
  WHERE assignment.station_id=p_station_id
  ORDER BY CASE assignment.approval_status WHEN 'approved' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END,
    p.last_name,p.first_name,assignment.valid_from DESC
  LIMIT p_limit;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_station_user_directory_atomic(uuid,uuid,integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_user_directory_atomic(uuid,uuid,integer) TO service_role;

CREATE OR REPLACE FUNCTION public.get_station_audit_log_atomic(
  p_actor_user_id uuid, p_station_id uuid, p_limit integer DEFAULT 100
)
RETURNS SETOF jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog, public AS $function$
BEGIN
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 250 THEN
    RAISE EXCEPTION 'invalid_station_audit_query' USING ERRCODE = '22023';
  END IF;
  IF NOT private.metra_lock_authorized_station_read(p_actor_user_id,p_station_id,'users.station.view') THEN
    RAISE EXCEPTION 'station_audit_forbidden' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY SELECT jsonb_build_object(
    'id',log.id,'entity_type',log.entity_type,'entity_id',log.entity_id,'action',log.action,
    'actor_id',log.actor_id,'reason',log.reason,'occurred_at',log.occurred_at,
    'target_user_id',COALESCE(log.after_data->>'user_id',log.before_data->>'user_id'),
    'role_code',COALESCE(log.after_data->>'assignment_role_code',log.after_data->>'role_code',
      log.before_data->>'assignment_role_code',log.before_data->>'role_code'),
    'previous_status',log.before_data->>'approval_status',
    'resulting_status',log.after_data->>'approval_status',
    'valid_from',COALESCE(log.after_data->>'valid_from',log.before_data->>'valid_from'),
    'valid_to',COALESCE(log.after_data->>'valid_to',log.before_data->>'valid_to'))
  FROM public.station_audit_log log
  WHERE (log.entity_type='station' AND log.entity_id=p_station_id)
    OR (log.entity_type='station_assignment' AND
      COALESCE(log.after_data->>'station_id',log.before_data->>'station_id')=p_station_id::text)
  ORDER BY log.occurred_at DESC,log.id DESC LIMIT p_limit;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_station_audit_log_atomic(uuid,uuid,integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_audit_log_atomic(uuid,uuid,integer) TO service_role;

CREATE OR REPLACE FUNCTION public.get_station_observation_review_queue_atomic(
  p_actor_user_id uuid, p_station_id uuid, p_limit integer DEFAULT 50
)
RETURNS SETOF jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog, public AS $function$
DECLARE v_allowed boolean := false; v_permission text;
BEGIN
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
    RAISE EXCEPTION 'invalid_observation_queue_query' USING ERRCODE = '22023';
  END IF;
  FOREACH v_permission IN ARRAY ARRAY['observation.review','observation.approve','observation.return_for_correction'] LOOP
    IF private.metra_lock_authorized_station_read(p_actor_user_id,p_station_id,v_permission) THEN
      v_allowed := true; EXIT;
    END IF;
  END LOOP;
  IF NOT v_allowed THEN RAISE EXCEPTION 'station_observation_queue_forbidden' USING ERRCODE = '42501'; END IF;
  RETURN QUERY SELECT jsonb_build_object(
    'id',o.id,'station_id',o.station_id,'created_by',o.created_by,'observation_type',o.observation_type,
    'observed_at',o.observed_at,'payload',o.payload,'status',o.status,
    'submitted_at',o.submitted_at,'created_at',o.created_at)
  FROM public.metra_observations o
  WHERE o.station_id=p_station_id AND o.status='submitted'
  ORDER BY o.observed_at DESC,o.created_at DESC,o.id DESC LIMIT p_limit;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_station_observation_review_queue_atomic(uuid,uuid,integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_observation_review_queue_atomic(uuid,uuid,integer) TO service_role;

COMMENT ON FUNCTION private.metra_lock_authorized_station_read(uuid,uuid,text) IS
'PROPOSAL ONLY: locks active account, station, authority, country, membership, assignment, role, role permission and grant FOR SHARE; protected projection must run in same RPC transaction.';
