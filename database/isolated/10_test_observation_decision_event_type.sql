-- Isolated regression for the canonical observation decision event vocabulary.
-- Requires the full operational schema, proposal 033 atomic authorization helper,
-- proposal 034 atomic observation write functions, and the event-type proposal.
-- Disposable PostgreSQL only; this transaction always rolls back.

BEGIN;

DO $$
DECLARE
  v_station uuid := '11111111-1111-1111-1111-111111111111';
  v_creator uuid := '22222222-2222-2222-2222-222222222222';
  v_reviewer uuid := '55555555-5555-5555-5555-555555555555';
  v_obs uuid;
  v_result jsonb;
  v_event text;
  v_status text;
BEGIN
  IF to_regclass('public.metra_observations') IS NULL
     OR to_regclass('public.metra_observation_audit_events') IS NULL
     OR to_regprocedure('private.metra_lock_authorized_station_read(uuid,uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'REQUIRED_ATOMIC_OBSERVATION_SCHEMA_MISSING';
  END IF;

  -- Override only the authorization helper inside this rollback-only test.
  -- Its real row-locking behavior is covered by the separate isolated RPC tests.
  EXECUTE $fn$
    CREATE OR REPLACE FUNCTION private.metra_lock_authorized_station_read(
      p_actor_user_id uuid, p_station_id uuid, p_permission_code text
    ) RETURNS boolean
    LANGUAGE sql STABLE
    AS $body$ SELECT true $body$;
  $fn$;

  INSERT INTO auth.users (id, email)
  VALUES
    (v_creator, 'event-type-creator@example.invalid'),
    (v_reviewer, 'event-type-reviewer@example.invalid')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.countries (id, is_active)
  VALUES ('33333333-3333-3333-3333-333333333333', true)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.meteorological_authorities (id, country_id, is_active)
  VALUES (
    '44444444-4444-4444-4444-444444444444',
    '33333333-3333-3333-3333-333333333333', true
  ) ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.station_catalogue (
    id, owner_authority_id, country_id, approval_status, operational_status, is_demo
  ) VALUES (
    v_station, '44444444-4444-4444-4444-444444444444',
    '33333333-3333-3333-3333-333333333333', 'approved', 'active', false
  ) ON CONFLICT (id) DO NOTHING;

  -- Approve: command token remains approve; stored status and audit event are approved.
  INSERT INTO public.metra_observations (
    id, station_id, created_by, observation_type, observed_at, payload,
    status, initial_status, idempotency_key, submitted_at
  ) VALUES (
    gen_random_uuid(), v_station, v_creator, 'hourly', now(), '{}'::jsonb,
    'submitted', 'submitted', 'test-decision-event-type-approve', now()
  ) RETURNING id INTO v_obs;

  SELECT public.metra_decide_observation(
    v_reviewer, v_station, v_obs, 'approve', 'reviewed'
  ) INTO v_result;

  IF (v_result->>'status') IS DISTINCT FROM 'approved' THEN
    RAISE EXCEPTION 'APPROVE_STATUS_MISMATCH: %', v_result;
  END IF;

  SELECT event_type INTO v_event
  FROM public.metra_observation_audit_events
  WHERE observation_id = v_obs
  ORDER BY occurred_at DESC LIMIT 1;

  IF v_event IS DISTINCT FROM 'approved' THEN
    RAISE EXCEPTION 'APPROVE_EVENT_TYPE_MISMATCH: got %', v_event;
  END IF;

  -- Return: requires a non-empty note and stores returned in both places.
  INSERT INTO public.metra_observations (
    id, station_id, created_by, observation_type, observed_at, payload,
    status, initial_status, idempotency_key, submitted_at
  ) VALUES (
    gen_random_uuid(), v_station, v_creator, 'hourly', now(), '{}'::jsonb,
    'submitted', 'submitted', 'test-decision-event-type-return', now()
  ) RETURNING id INTO v_obs;

  BEGIN
    PERFORM public.metra_decide_observation(
      v_reviewer, v_station, v_obs, 'return_for_correction', NULL
    );
    RAISE EXCEPTION 'RETURN_WITHOUT_NOTE_WAS_ACCEPTED';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    IF SQLERRM <> 'decision_note_required' THEN RAISE; END IF;
  END;

  SELECT status INTO v_status FROM public.metra_observations WHERE id = v_obs;
  IF v_status IS DISTINCT FROM 'submitted' THEN
    RAISE EXCEPTION 'RETURN_WITHOUT_NOTE_CHANGED_STATUS: %', v_status;
  END IF;

  SELECT public.metra_decide_observation(
    v_reviewer, v_station, v_obs, 'return_for_correction', 'needs correction'
  ) INTO v_result;

  IF (v_result->>'status') IS DISTINCT FROM 'returned' THEN
    RAISE EXCEPTION 'RETURN_STATUS_MISMATCH: %', v_result;
  END IF;

  SELECT event_type INTO v_event
  FROM public.metra_observation_audit_events
  WHERE observation_id = v_obs
  ORDER BY occurred_at DESC LIMIT 1;

  IF v_event IS DISTINCT FROM 'returned' THEN
    RAISE EXCEPTION 'RETURN_EVENT_TYPE_MISMATCH: got %', v_event;
  END IF;

  -- A user cannot review their own observation, even with the test helper allowing permission.
  INSERT INTO public.metra_observations (
    id, station_id, created_by, observation_type, observed_at, payload,
    status, initial_status, idempotency_key, submitted_at
  ) VALUES (
    gen_random_uuid(), v_station, v_reviewer, 'hourly', now(), '{}'::jsonb,
    'submitted', 'submitted', 'test-decision-event-type-self-review', now()
  ) RETURNING id INTO v_obs;

  BEGIN
    PERFORM public.metra_decide_observation(
      v_reviewer, v_station, v_obs, 'approve', 'self review'
    );
    RAISE EXCEPTION 'SELF_REVIEW_WAS_ACCEPTED';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    IF SQLERRM <> 'self_review_forbidden' THEN RAISE; END IF;
  END;

  RAISE NOTICE 'PASS: canonical event vocabulary, atomic permission helper, required return note, and self-review denial verified';
END;
$$;

ROLLBACK;
