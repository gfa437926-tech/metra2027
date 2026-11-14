-- Isolated regression: metra_decide_observation must write event_type
-- that satisfies the CHECK on metra_observation_audit_events.
--
-- Run against a disposable PostgreSQL instance that has applied the
-- operational observation schema + the proposed unify migration.
-- This file is intentionally self-contained for CI; it does not touch
-- any hosted Supabase project.

begin;

-- Minimal fixtures (ids are fixed for repeatability).
do $$
declare
  v_station uuid := '11111111-1111-1111-1111-111111111111';
  v_user    uuid := '22222222-2222-2222-2222-222222222222';
  v_obs     uuid;
  v_result  jsonb;
  v_event   text;
begin
  -- This regression must run against the complete operational observation schema.
  -- Missing prerequisites are a hard failure, never a successful SKIP.
  if to_regclass('public.metra_observations') is null
     or to_regclass('public.metra_observation_audit_events') is null then
    raise exception 'REQUIRED_OBSERVATION_SCHEMA_MISSING';
  end if;

  -- Permission stub: allow both decision permissions for the test actor.
  -- Real deployments use metra_user_has_station_permission; for isolation we
  -- replace it only inside this transaction if the function exists.
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'metra_user_has_station_permission'
  ) then
    execute $fn$
      create or replace function public.metra_user_has_station_permission(
        p_user_id uuid, p_station_id uuid, p_permission_code text
      ) returns boolean language sql stable as $s$
        select true;
      $s$
    $fn$;
  end if;

  -- Build the minimum FK fixture required by the real operational schema.
  insert into auth.users (id, email)
  values (v_user, 'event-type-regression@example.invalid')
  on conflict (id) do nothing;

  insert into public.countries (id, is_active)
  values ('33333333-3333-3333-3333-333333333333', true)
  on conflict (id) do nothing;

  insert into public.meteorological_authorities (id, country_id, is_active)
  values (
    '44444444-4444-4444-4444-444444444444',
    '33333333-3333-3333-3333-333333333333', true
  ) on conflict (id) do nothing;

  insert into public.station_catalogue (
    id, owner_authority_id, country_id, approval_status, operational_status, is_demo
  ) values (
    v_station,
    '44444444-4444-4444-4444-444444444444',
    '33333333-3333-3333-3333-333333333333',
    'approved', 'active', false
  ) on conflict (id) do nothing;

  -- Insert a submitted observation directly (bypassing submit RPC for focus).
  insert into public.metra_observations (
    id, station_id, created_by, observation_type, observed_at, payload,
    status, initial_status, idempotency_key, submitted_at
  ) values (
    gen_random_uuid(), v_station, v_user, 'hourly', now(), '{}'::jsonb,
    'submitted', 'submitted', 'test-decision-event-type-1', now()
  )
  returning id into v_obs;

  -- Approve path: event_type must be 'approved'.
  select public.metra_decide_observation(
    v_user, v_station, v_obs, 'approve', 'ok'
  ) into v_result;

  if (v_result->>'status') is distinct from 'approved' then
    raise exception 'APPROVE_STATUS_MISMATCH: %', v_result;
  end if;

  select event_type into v_event
    from public.metra_observation_audit_events
   where observation_id = v_obs
   order by occurred_at desc
   limit 1;

  if v_event is distinct from 'approved' then
    raise exception 'APPROVE_EVENT_TYPE_MISMATCH: got %', v_event;
  end if;

  -- Second observation for return path.
  insert into public.metra_observations (
    id, station_id, created_by, observation_type, observed_at, payload,
    status, initial_status, idempotency_key, submitted_at
  ) values (
    gen_random_uuid(), v_station, v_user, 'hourly', now(), '{}'::jsonb,
    'submitted', 'submitted', 'test-decision-event-type-2', now()
  )
  returning id into v_obs;

  select public.metra_decide_observation(
    v_user, v_station, v_obs, 'return_for_correction', 'needs fix'
  ) into v_result;

  if (v_result->>'status') is distinct from 'returned' then
    raise exception 'RETURN_STATUS_MISMATCH: %', v_result;
  end if;

  select event_type into v_event
    from public.metra_observation_audit_events
   where observation_id = v_obs
   order by occurred_at desc
   limit 1;

  if v_event is distinct from 'returned' then
    raise exception 'RETURN_EVENT_TYPE_MISMATCH: got %', v_event;
  end if;

  raise notice 'PASS: observation decision event_type unified to approved/returned';
end;
$$;

rollback;
