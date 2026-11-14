-- PROPOSAL ONLY — DO NOT APPLY TO HOSTED SUPABASE WITHOUT EXPLICIT OWNER APPROVAL.
--
-- Canonical decision vocabulary:
--   API/UI commands: approve | return_for_correction
--   stored status + audit event_type: approved | returned
--
-- This definition intentionally preserves C9.7's atomic authorization contract:
--   * authorization facts are locked in the same transaction as the decision;
--   * self-review is forbidden;
--   * return-for-correction requires a non-empty note;
--   * observation row is locked and must still be submitted.
-- The migration changes only the event/status vocabulary, not the security model.

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
SET search_path = pg_catalog, public, private
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
  IF NOT private.metra_lock_authorized_station_read(
    p_user_id, p_station_id, v_permission
  ) THEN
    RAISE EXCEPTION 'station_observation_decision_forbidden' USING ERRCODE = '42501';
  END IF;

  v_status := CASE
    WHEN p_decision = 'approve' THEN 'approved'
    ELSE 'returned'
  END;

  UPDATE public.metra_observations
  SET status = v_status,
      reviewed_by = p_user_id,
      reviewed_at = now(),
      review_note = v_note,
      updated_at = now()
  WHERE id = p_observation_id
    AND station_id = p_station_id
    AND status = 'submitted';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'observation_not_in_submitted_state' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.metra_observation_audit_events (
    observation_id, station_id, actor_user_id, event_type,
    from_status, to_status, note
  ) VALUES (
    p_observation_id, p_station_id, p_user_id, v_status,
    'submitted', v_status, v_note
  );

  RETURN jsonb_build_object(
    'id', p_observation_id,
    'status', v_status,
    'replayed', false
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.metra_decide_observation(uuid,uuid,uuid,text,text)
  FROM PUBLIC, anon, authenticated, metra_api_runtime;
GRANT EXECUTE ON FUNCTION public.metra_decide_observation(uuid,uuid,uuid,text,text)
  TO service_role;

COMMENT ON FUNCTION public.metra_decide_observation(uuid,uuid,uuid,text,text) IS
  'Atomic station-authorized observation decision. API commands approve|return_for_correction; stored status and audit event_type approved|returned. Self-review is forbidden and return requires a note. Proposal 2026-11-14.';
