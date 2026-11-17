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
     OR p_permission_code IS NULL OR p_permission_code NOT IN ('users.station.view','observation.review','observation.archive.read','observation.create','observation.submit','observation.approve','observation.return_for_correction') THEN
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
      AND m.approval_status = 'approved' AND m.approved_by IS NOT NULL AND m.reviewed_at IS NOT NULL
      AND m.valid_from <= v_now AND (m.valid_to IS NULL OR m.valid_to > v_now)
      AND sa.approval_status = 'approved'
    AND sa.approved_by IS NOT NULL AND sa.reviewed_at IS NOT NULL
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
      AND m.approval_status = 'approved' AND m.approved_by IS NOT NULL AND m.reviewed_at IS NOT NULL
      AND m.valid_from <= v_now AND (m.valid_to IS NULL OR m.valid_to > v_now)
      AND sa.approval_status = 'approved'
    AND sa.approved_by IS NOT NULL AND sa.reviewed_at IS NOT NULL
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
'PROPOSAL ONLY: locks active account, station, authority, country, membership, assignment, role, role permission and grant FOR SHARE; protected read or write must run in the same RPC transaction.';


-- Station-bound historical archive reads. The live schema's permission_grants
-- is authority-scoped (it has no station_id); station scope is therefore enforced
-- by the actor's active station_assignments row inside the same transaction.
CREATE OR REPLACE FUNCTION public.get_station_observation_archive_atomic(
  p_actor_user_id uuid,
  p_station_id uuid,
  p_from_utc timestamptz DEFAULT NULL,
  p_to_utc timestamptz DEFAULT NULL,
  p_observation_type text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_cursor text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public, private
AS $function$
DECLARE
  v_cursor_sort_at timestamptz := NULL;
  v_cursor_id uuid := NULL;
  v_has_more boolean := false;
  v_next_cursor text := NULL;
  v_items jsonb := '[]'::jsonb;
BEGIN
  IF p_actor_user_id IS NULL OR p_station_id IS NULL THEN
    RAISE EXCEPTION 'archive_actor_and_station_required' USING ERRCODE = '22023';
  END IF;
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
    RAISE EXCEPTION 'invalid_archive_limit' USING ERRCODE = '22023';
  END IF;
  IF p_from_utc IS NOT NULL AND p_to_utc IS NOT NULL AND p_from_utc >= p_to_utc THEN
    RAISE EXCEPTION 'invalid_archive_date_range' USING ERRCODE = '22023';
  END IF;
  IF p_observation_type IS NOT NULL AND p_observation_type NOT IN
    ('hourly','daily','climate','soil','agricultural','phenomenon','fieldclimate') THEN
    RAISE EXCEPTION 'invalid_archive_observation_type' USING ERRCODE = '22023';
  END IF;
  IF p_cursor IS NOT NULL THEN
    IF length(p_cursor) > 200 THEN
      RAISE EXCEPTION 'invalid_archive_cursor' USING ERRCODE = '22023';
    END IF;
    BEGIN
      v_cursor_sort_at := split_part(p_cursor, '|', 1)::timestamptz;
      v_cursor_id := split_part(p_cursor, '|', 2)::uuid;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'invalid_archive_cursor' USING ERRCODE = '22023';
    END;
  END IF;

  IF NOT private.metra_lock_authorized_station_read(
    p_actor_user_id, p_station_id, 'observation.archive.read'
  ) THEN
    RAISE EXCEPTION 'station_observation_archive_forbidden' USING ERRCODE = '42501';
  END IF;

  WITH filtered AS MATERIALIZED (
    SELECT o.id, o.station_id, o.observation_type, o.observed_at, o.imported_at,
      o.source_system, o.source_table, o.source_record_id, o.payload,
      COALESCE(o.observed_at, o.imported_at) AS sort_at
    FROM public.metra_observation_records o
    WHERE o.station_id = p_station_id
      AND o.is_demo = false
      AND (p_from_utc IS NULL OR (o.observed_at IS NOT NULL AND o.observed_at >= p_from_utc))
      AND (p_to_utc IS NULL OR (o.observed_at IS NOT NULL AND o.observed_at < p_to_utc))
      AND (p_observation_type IS NULL OR o.observation_type = p_observation_type)
      AND (v_cursor_sort_at IS NULL OR
        (COALESCE(o.observed_at, o.imported_at), o.id) < (v_cursor_sort_at, v_cursor_id))
    ORDER BY sort_at DESC, o.id DESC
    LIMIT p_limit + 1
  ),
  page AS (
    SELECT * FROM filtered
    ORDER BY sort_at DESC, id DESC
    LIMIT p_limit
  ),
  stats AS (
    SELECT count(*) > p_limit AS has_more FROM filtered
  ),
  last_item AS (
    SELECT sort_at, id FROM page
    ORDER BY sort_at ASC, id ASC
    LIMIT 1
  )
  SELECT
    COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', p.id::text,
        'stationId', p.station_id::text,
        'observationType', p.observation_type,
        'observedAtUtc', p.observed_at,
        'importedAtUtc', p.imported_at,
        'sourceSystem', p.source_system,
        'sourceTable', p.source_table,
        'sourceRecordId', p.source_record_id,
        'payload', CASE
          WHEN jsonb_typeof(p.payload) = 'object' THEN p.payload - ARRAY[
            'id','station_id','station','station_name','user_station','raw_data',
            'report_id','status','validation_status','approval_confirmed',
            'responsibility_confirmed','responsibility_agreed','is_draft',
            'supabase_success','whatsapp_shared','shared_at','submitted_at',
            'updated_at','created_at','submission_date','submission_time',
            'submission_timestamp','recorded_at','fetched_at','is_shared_with_station'
          ]::text[]
          ELSE '{}'::jsonb
        END
      ) ORDER BY p.sort_at DESC, p.id DESC)
      FROM page p
    ), '[]'::jsonb),
    (SELECT has_more FROM stats),
    CASE WHEN (SELECT has_more FROM stats)
      THEN (SELECT sort_at::text || '|' || id::text FROM last_item)
      ELSE NULL
    END
  INTO v_items, v_has_more, v_next_cursor;

  RETURN jsonb_build_object(
    'items', v_items,
    'hasMore', v_has_more,
    'nextCursor', v_next_cursor
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_station_observation_archive_atomic(uuid,uuid,timestamptz,timestamptz,text,integer,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_observation_archive_atomic(uuid,uuid,timestamptz,timestamptz,text,integer,text)
  TO service_role;

CREATE OR REPLACE FUNCTION public.get_station_observation_archive_item_atomic(
  p_actor_user_id uuid,
  p_station_id uuid,
  p_observation_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public, private
AS $function$
DECLARE v_item jsonb;
BEGIN
  IF p_actor_user_id IS NULL OR p_station_id IS NULL OR p_observation_id IS NULL THEN
    RAISE EXCEPTION 'archive_identifiers_required' USING ERRCODE = '22023';
  END IF;
  IF NOT private.metra_lock_authorized_station_read(
    p_actor_user_id, p_station_id, 'observation.archive.read'
  ) THEN
    RAISE EXCEPTION 'station_observation_archive_forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'id', o.id::text,
    'stationId', o.station_id::text,
    'observationType', o.observation_type,
    'observedAtUtc', o.observed_at,
    'importedAtUtc', o.imported_at,
    'sourceSystem', o.source_system,
    'sourceTable', o.source_table,
    'sourceRecordId', o.source_record_id,
    'payload', CASE
      WHEN jsonb_typeof(o.payload) = 'object' THEN o.payload - ARRAY[
        'id','station_id','station','station_name','user_station','raw_data',
        'report_id','status','validation_status','approval_confirmed',
        'responsibility_confirmed','responsibility_agreed','is_draft',
        'supabase_success','whatsapp_shared','shared_at','submitted_at',
        'updated_at','created_at','submission_date','submission_time',
        'submission_timestamp','recorded_at','fetched_at','is_shared_with_station'
      ]::text[]
      ELSE '{}'::jsonb
    END
  )
  INTO v_item
  FROM public.metra_observation_records o
  WHERE o.id = p_observation_id
    AND o.station_id = p_station_id
    AND o.is_demo = false;

  RETURN v_item;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_station_observation_archive_item_atomic(uuid,uuid,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_observation_archive_item_atomic(uuid,uuid,uuid)
  TO service_role;

COMMENT ON FUNCTION public.get_station_observation_archive_atomic(uuid,uuid,timestamptz,timestamptz,text,integer,text) IS
  'Actor-bound station archive list. Locks authorization facts in the same transaction; excludes unlinked/demo records and removes workflow/private metadata from payload.';
