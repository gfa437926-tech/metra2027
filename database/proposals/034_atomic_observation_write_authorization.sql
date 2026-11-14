-- C9.7: make observation submission and decisions atomic with authorization.
-- The actor ID is supplied only by the trusted .NET API from the validated JWT subject.
-- This proposal is for isolated verification first; do not apply to hosted Supabase without approval.

CREATE OR REPLACE FUNCTION public.metra_submit_observation(
  p_user_id uuid,
  p_station_id uuid,
  p_idempotency_key text,
  p_observation_type text,
  p_observed_at timestamptz,
  p_payload jsonb,
  p_submit boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_observation public.metra_observations%rowtype;
  v_initial_status text;
BEGIN
  IF p_user_id IS NULL OR p_station_id IS NULL THEN
    RAISE EXCEPTION 'user_id_and_station_id_required' USING ERRCODE = '22023';
  END IF;
  IF p_idempotency_key IS NULL OR length(btrim(p_idempotency_key)) NOT BETWEEN 1 AND 128 THEN
    RAISE EXCEPTION 'invalid_idempotency_key' USING ERRCODE = '22023';
  END IF;
  IF p_observation_type IS NULL OR p_observation_type NOT IN ('daily','hourly','phenomenon') THEN
    RAISE EXCEPTION 'invalid_observation_type' USING ERRCODE = '22023';
  END IF;
  IF p_observed_at IS NULL OR p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object'
     OR pg_column_size(p_payload) > 65536 THEN
    RAISE EXCEPTION 'invalid_observation_payload' USING ERRCODE = '22023';
  END IF;

  IF NOT private.metra_lock_authorized_station_read(p_user_id,p_station_id,'observation.create') THEN
    RAISE EXCEPTION 'station_observation_create_forbidden' USING ERRCODE = '42501';
  END IF;
  IF coalesce(p_submit,false) AND
     NOT private.metra_lock_authorized_station_read(p_user_id,p_station_id,'observation.submit') THEN
    RAISE EXCEPTION 'station_observation_submit_forbidden' USING ERRCODE = '42501';
  END IF;

  v_initial_status := CASE WHEN coalesce(p_submit,false) THEN 'submitted' ELSE 'draft' END;

  INSERT INTO public.metra_observations (
    station_id, created_by, observation_type, observed_at, payload,
    status, initial_status, idempotency_key, submitted_at
  ) VALUES (
    p_station_id, p_user_id, p_observation_type, p_observed_at, p_payload,
    v_initial_status, v_initial_status, p_idempotency_key,
    CASE WHEN v_initial_status = 'submitted' THEN now() ELSE NULL END
  )
  ON CONFLICT (station_id, created_by, idempotency_key) DO NOTHING
  RETURNING * INTO v_observation;

  IF v_observation.id IS NULL THEN
    SELECT * INTO v_observation
    FROM public.metra_observations
    WHERE station_id = p_station_id
      AND created_by = p_user_id
      AND idempotency_key = p_idempotency_key
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'idempotent_observation_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_observation.observation_type <> p_observation_type
       OR v_observation.observed_at <> p_observed_at
       OR v_observation.payload <> p_payload
       OR v_observation.initial_status <> v_initial_status THEN
      RAISE EXCEPTION 'idempotency_key_reused_with_different_request'
        USING ERRCODE = '23505';
    END IF;

    RETURN jsonb_build_object(
      'id',v_observation.id,'status',v_observation.status,'replayed',true
    );
  END IF;

  INSERT INTO public.metra_observation_audit_events (
    observation_id,station_id,actor_user_id,event_type,from_status,to_status
  ) VALUES (
    v_observation.id,p_station_id,p_user_id,
    CASE WHEN v_initial_status='submitted' THEN 'submitted' ELSE 'created_draft' END,
    NULL,v_initial_status
  );

  RETURN jsonb_build_object(
    'id',v_observation.id,'status',v_observation.status,'replayed',false
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.metra_submit_observation(uuid,uuid,text,text,timestamptz,jsonb,boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.metra_submit_observation(uuid,uuid,text,text,timestamptz,jsonb,boolean)
  TO service_role;

CREATE OR REPLACE FUNCTION public.metra_decide_observation(
  p_user_id uuid,
  p_station_id uuid,
  p_observation_id uuid,
  p_decision text,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_row public.metra_observations%rowtype;
  v_permission text;
  v_status text;
  v_note text;
BEGIN
  IF p_user_id IS NULL OR p_station_id IS NULL OR p_observation_id IS NULL THEN
    RAISE EXCEPTION 'user_station_observation_required' USING ERRCODE = '22023';
  END IF;
  IF p_decision IS NULL OR p_decision NOT IN ('approve','return_for_correction') THEN
    RAISE EXCEPTION 'invalid_observation_decision' USING ERRCODE = '22023';
  END IF;

  v_note := nullif(btrim(coalesce(p_note,'')),'');
  IF p_note IS NOT NULL AND length(p_note) > 2000 THEN
    RAISE EXCEPTION 'decision_note_too_long' USING ERRCODE = '22023';
  END IF;
  IF p_decision = 'return_for_correction' AND v_note IS NULL THEN
    RAISE EXCEPTION 'decision_note_required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row
  FROM public.metra_observations
  WHERE id = p_observation_id AND station_id = p_station_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'observation_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_row.status <> 'submitted' THEN
    RAISE EXCEPTION 'observation_not_in_submitted_state' USING ERRCODE = '22023';
  END IF;
  IF v_row.created_by = p_user_id THEN
    RAISE EXCEPTION 'self_review_forbidden' USING ERRCODE = '42501';
  END IF;

  v_permission := CASE
    WHEN p_decision = 'approve' THEN 'observation.approve'
    ELSE 'observation.return_for_correction'
  END;
  IF NOT private.metra_lock_authorized_station_read(p_user_id,p_station_id,v_permission) THEN
    RAISE EXCEPTION 'station_observation_decision_forbidden' USING ERRCODE = '42501';
  END IF;

  v_status := CASE WHEN p_decision='approve' THEN 'approved' ELSE 'returned' END;

  UPDATE public.metra_observations
  SET status=v_status, reviewed_by=p_user_id, reviewed_at=now(),
      review_note=v_note, updated_at=now()
  WHERE id=p_observation_id AND station_id=p_station_id AND status='submitted';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'observation_not_in_submitted_state' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.metra_observation_audit_events (
    observation_id,station_id,actor_user_id,event_type,from_status,to_status,note
  ) VALUES (
    p_observation_id,p_station_id,p_user_id,v_status,'submitted',v_status,v_note
  );

  RETURN jsonb_build_object('id',p_observation_id,'status',v_status,'replayed',false);
END;
$function$;

REVOKE ALL ON FUNCTION public.metra_decide_observation(uuid,uuid,uuid,text,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.metra_decide_observation(uuid,uuid,uuid,text,text)
  TO service_role;

COMMENT ON FUNCTION public.metra_submit_observation(uuid,uuid,text,text,timestamptz,jsonb,boolean) IS
  'Actor-bound observation write; permission and station assignment rows are locked in the same transaction as insert.';
COMMENT ON FUNCTION public.metra_decide_observation(uuid,uuid,uuid,text,text) IS
  'Actor-bound observation decision; permission and station assignment rows are locked in the same transaction as status transition.';
