-- Authority-scope the second-stage registration review, queue and audit.
-- The first-stage station-head workflow remains station-assignment scoped.
CREATE OR REPLACE FUNCTION public.decide_metra_registration_for_station(
  p_request_id uuid,
  p_station_id uuid,
  p_expected_status text,
  p_actor_user_id uuid,
  p_decision text,
  p_note text,
  p_occurred_at timestamptz
)
RETURNS TABLE(result_status text, resulting_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $function$
DECLARE
  v_authority_id uuid;
  v_now timestamptz := clock_timestamp();
BEGIN
  IF p_request_id IS NULL OR p_station_id IS NULL OR p_actor_user_id IS NULL
     OR p_actor_user_id = '00000000-0000-0000-0000-000000000000'::uuid THEN
    RAISE EXCEPTION 'registration_request_station_and_actor_required' USING ERRCODE = '22023';
  END IF;

  IF p_expected_status = 'pending_system_approval' THEN
    SELECT s.owner_authority_id INTO v_authority_id
      FROM public.station_catalogue s
      JOIN public.meteorological_authorities a
        ON a.id = s.owner_authority_id AND a.country_id = s.country_id
      JOIN public.countries c ON c.id = s.country_id
     WHERE s.id = p_station_id
       AND s.is_demo = FALSE
       AND s.approval_status = 'approved'
       AND s.operational_status = 'active'
       AND a.is_active = TRUE AND c.is_active = TRUE
     FOR SHARE OF s, a, c;
    IF v_authority_id IS NULL THEN
      RETURN QUERY SELECT 'unauthorized'::text, NULL::text;
      RETURN;
    END IF;

    PERFORM 1 FROM public.metra_account_states a
     WHERE a.user_id = p_actor_user_id AND a.account_state = 'active'
     FOR SHARE;
    IF NOT FOUND THEN
      RETURN QUERY SELECT 'unauthorized'::text, NULL::text;
      RETURN;
    END IF;

    PERFORM 1
      FROM public.authority_memberships m
      JOIN public.metra_role_catalogue r
        ON r.role_code = m.membership_role_code AND r.is_active = TRUE
      JOIN public.metra_role_permissions rp
        ON rp.role_code = r.role_code
       AND rp.permission_code = 'registrations.system.approve'
     WHERE m.user_id = p_actor_user_id
       AND m.authority_id = v_authority_id
       AND m.approval_status = 'approved'
       AND m.valid_from <= v_now
       AND (m.valid_to IS NULL OR m.valid_to > v_now)
     FOR SHARE OF m, r, rp;
    IF NOT FOUND THEN
      RETURN QUERY SELECT 'unauthorized'::text, NULL::text;
      RETURN;
    END IF;

    PERFORM 1 FROM public.permission_grants g
     WHERE g.user_id = p_actor_user_id
       AND g.permission_code = 'registrations.system.approve'
       AND g.approval_status = 'approved'
       AND g.revoked_at IS NULL
       AND g.valid_from <= v_now
       AND (g.valid_to IS NULL OR g.valid_to > v_now)
     FOR SHARE;
    IF NOT FOUND THEN
      RETURN QUERY SELECT 'unauthorized'::text, NULL::text;
      RETURN;
    END IF;
  ELSIF p_expected_status <> 'pending_station_approval' THEN
    RAISE EXCEPTION 'invalid_registration_stage' USING ERRCODE = '22023';
  END IF;

  -- This existing transactional operation retains request/station binding,
  -- two-stage state checks, distinct reviewers and append-only audit events.
  RETURN QUERY
    SELECT d.result_status, d.resulting_status
      FROM public.decide_metra_registration(
        p_request_id, p_expected_status, p_actor_user_id,
        p_decision, p_note, p_occurred_at
      ) d;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_station_system_registration_queue(
  p_station_id uuid,
  p_expected_status text,
  p_limit integer DEFAULT 50,
  p_actor_user_id uuid DEFAULT NULL
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  IF p_station_id IS NULL OR p_actor_user_id IS NULL
     OR p_expected_status IS DISTINCT FROM 'pending_system_approval'
     OR p_limit IS NULL OR p_limit < 1 OR p_limit > 100
     OR NOT public.metra_user_has_station_owner_authority_permission(
       p_actor_user_id, p_station_id, 'registrations.system.approve'
     ) THEN
    RAISE EXCEPTION 'system_registration_queue_forbidden_or_invalid' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
    SELECT q FROM public.get_station_registration_queue(
      p_station_id, 'pending_system_approval', p_limit
    ) q;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_station_system_registration_audit(
  p_station_id uuid,
  p_limit integer DEFAULT 100,
  p_actor_user_id uuid DEFAULT NULL
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  IF p_station_id IS NULL OR p_actor_user_id IS NULL
     OR p_limit IS NULL OR p_limit < 1 OR p_limit > 200
     OR NOT public.metra_user_has_station_owner_authority_permission(
       p_actor_user_id, p_station_id, 'registrations.system.approve'
     ) THEN
    RAISE EXCEPTION 'system_registration_audit_forbidden_or_invalid' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
    SELECT e FROM public.get_station_registration_audit(p_station_id, p_limit) e;
END;
$function$;

REVOKE ALL ON FUNCTION public.decide_metra_registration_for_station(uuid,uuid,text,uuid,text,text,timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.decide_metra_registration_for_station(uuid,uuid,text,uuid,text,text,timestamptz)
  TO service_role;
REVOKE ALL ON FUNCTION public.get_station_system_registration_queue(uuid,text,integer,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_system_registration_queue(uuid,text,integer,uuid)
  TO service_role;
REVOKE ALL ON FUNCTION public.get_station_system_registration_audit(uuid,integer,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_system_registration_audit(uuid,integer,uuid)
  TO service_role;
