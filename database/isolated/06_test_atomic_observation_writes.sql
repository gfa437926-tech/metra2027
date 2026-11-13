\set ON_ERROR_STOP on
DO $$
DECLARE
  observer uuid := '11111111-1111-1111-1111-111111111111';
  reviewer uuid := '22222222-2222-2222-2222-222222222222';
  chief_auditor uuid := '33333333-3333-3333-3333-333333333333';
  station_a uuid := 'aaaaaaaa-0001-0001-0001-000000000001';
  station_b uuid := 'aaaaaaaa-0002-0002-0002-000000000002';
  submitted jsonb;
  replayed jsonb;
  decision jsonb;
  observation_id uuid;
  second_id uuid;
  self_id uuid;
  grant_id uuid;
  status_value text;
BEGIN
  submitted := public.metra_submit_observation(
    observer,station_a,'atomic-write-hourly-001','hourly',
    '2026-11-13T00:00:00Z','{"dryTemp":"+20.0"}'::jsonb,true);
  observation_id := (submitted->>'id')::uuid;
  IF submitted->>'status' <> 'submitted' OR submitted->>'replayed' <> 'false' THEN
    RAISE EXCEPTION 'new observation was not submitted'; END IF;

  replayed := public.metra_submit_observation(
    observer,station_a,'atomic-write-hourly-001','hourly',
    '2026-11-13T00:00:00Z','{"dryTemp":"+20.0"}'::jsonb,true);
  IF replayed->>'id' <> observation_id::text OR replayed->>'replayed' <> 'true' THEN
    RAISE EXCEPTION 'idempotent retry was not replayed'; END IF;

  BEGIN
    PERFORM public.metra_submit_observation(
      observer,station_b,'atomic-write-cross-station','hourly',
      '2026-11-13T01:00:00Z','{"dryTemp":"+21.0"}'::jsonb,true);
    RAISE EXCEPTION 'cross-station submission unexpectedly succeeded';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

  decision := public.metra_decide_observation(
    reviewer,station_a,observation_id,'return_for_correction','Correct the dry temperature value.');
  IF decision->>'status' <> 'returned' THEN
    RAISE EXCEPTION 'station head did not return the observation'; END IF;

  submitted := public.metra_submit_observation(
    observer,station_a,'atomic-write-approve-002','daily',
    '2026-11-13T00:00:00Z','{"reportType":"24h"}'::jsonb,true);
  second_id := (submitted->>'id')::uuid;
  decision := public.metra_decide_observation(
    chief_auditor,station_a,second_id,'approve',NULL);
  IF decision->>'status' <> 'approved' THEN
    RAISE EXCEPTION 'chief auditor did not approve the observation'; END IF;

  submitted := public.metra_submit_observation(
    observer,station_a,'atomic-write-self-review-003','hourly',
    '2026-11-13T02:00:00Z','{"dryTemp":"+22.0"}'::jsonb,true);
  self_id := (submitted->>'id')::uuid;
  BEGIN
    PERFORM public.metra_decide_observation(
      observer,station_a,self_id,'return_for_correction','self review');
    RAISE EXCEPTION 'self review unexpectedly succeeded';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

  SELECT id INTO grant_id FROM public.permission_grants
   WHERE user_id=observer AND authority_id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
     AND permission_code='observation.submit';
  UPDATE public.permission_grants SET revoked_at=now() WHERE id=grant_id;
  BEGIN
    PERFORM public.metra_submit_observation(
      observer,station_a,'atomic-write-revoked-submit','hourly',
      '2026-11-13T03:00:00Z','{"dryTemp":"+23.0"}'::jsonb,true);
    RAISE EXCEPTION 'revoked submit permission unexpectedly succeeded';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
  UPDATE public.permission_grants SET revoked_at=NULL WHERE id=grant_id;

  UPDATE public.station_assignments SET valid_to=now()-interval '1 second'
   WHERE user_id=observer AND station_id=station_a;
  BEGIN
    PERFORM public.metra_submit_observation(
      observer,station_a,'atomic-write-expired-assignment','hourly',
      '2026-11-13T04:00:00Z','{"dryTemp":"+24.0"}'::jsonb,true);
    RAISE EXCEPTION 'expired station assignment unexpectedly submitted';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

  SELECT status INTO status_value FROM public.metra_observations WHERE id=observation_id;
  IF status_value <> 'returned' THEN RAISE EXCEPTION 'unexpected final status for returned record'; END IF;

  -- Restore the fixture after the negative assignment-expiry assertion.
  -- The following concurrency suite depends on an active observer assignment.
  UPDATE public.station_assignments SET valid_to=NULL
   WHERE user_id=observer AND station_id=station_a;

  RAISE NOTICE 'PASS: atomic submit, idempotent replay, cross-station denial, return, approve, self-review denial, revoked grant and expired assignment';
END $$;
