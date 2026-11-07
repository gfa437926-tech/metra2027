-- Scenarios executed after applying the real migration files.
-- Must fail hard on unexpected success of protected operations.

-- Seed
insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222'),
  ('33333333-3333-4333-8333-333333333333')
on conflict do nothing;

insert into public.station_catalogue(id, name) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'station-a'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'station-b')
on conflict do nothing;

insert into public._test_station_permissions values
  ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.submit'),
  ('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.approve'),
  ('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.return_for_correction'),
  ('33333333-3333-4333-8333-333333333333', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.approve')
on conflict do nothing;

insert into public.metra_observations (
  id, station_id, created_by, observation_type, observed_at, payload,
  status, initial_status, idempotency_key, submitted_at
) values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  'hourly', now(), '{}'::jsonb,
  'submitted', 'submitted', 'key-1', now()
) on conflict do nothing;

-- 1) Self-review must fail with the expected protected error.
do $$
declare
  raised boolean := false;
begin
  begin
    perform public.metra_decide_observation(
      '11111111-1111-4111-8111-111111111111',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'approve', null);
  exception
    when others then
      if sqlerrm like '%self_review_forbidden%' then
        raised := true;
      else
        raise exception 'TEST_FAIL: self-review raised unexpected error: %', sqlerrm;
      end if;
  end;
  if not raised then
    raise exception 'TEST_FAIL: self-review was allowed';
  end if;
end $$;

-- 2) Cross-station decision must fail.
do $$
declare
  raised boolean := false;
begin
  begin
    perform public.metra_decide_observation(
      '22222222-2222-4222-8222-222222222222',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'approve', null);
  exception
    when others then
      if sqlerrm like '%observation_not_found%' then
        raised := true;
      else
        raise exception 'TEST_FAIL: cross-station raised unexpected error: %', sqlerrm;
      end if;
  end;
  if not raised then
    raise exception 'TEST_FAIL: cross-station decision was allowed';
  end if;
end $$;

-- 3) Unauthorized decision codes must fail.
do $$
declare
  raised boolean := false;
begin
  begin
    perform public.metra_decide_observation(
      '22222222-2222-4222-8222-222222222222',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'reject', null);
  exception
    when others then
      if sqlerrm like '%invalid_observation_decision%' then
        raised := true;
      else
        raise exception 'TEST_FAIL: invalid decision raised unexpected error: %', sqlerrm;
      end if;
  end;
  if not raised then
    raise exception 'TEST_FAIL: invalid decision was allowed';
  end if;
end $$;

-- 4) Return without note must fail.
insert into public.metra_observations (
  id, station_id, created_by, observation_type, observed_at, payload,
  status, initial_status, idempotency_key, submitted_at
) values (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  'daily', now(), '{}'::jsonb,
  'submitted', 'submitted', 'key-2', now()
) on conflict do nothing;

do $$
declare
  raised boolean := false;
begin
  begin
    perform public.metra_decide_observation(
      '22222222-2222-4222-8222-222222222222',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      'return_for_correction', null);
  exception
    when others then
      if sqlerrm like '%decision_note_required%' then
        raised := true;
      else
        raise exception 'TEST_FAIL: return-without-note unexpected error: %', sqlerrm;
      end if;
  end;
  if not raised then
    raise exception 'TEST_FAIL: return without note was allowed';
  end if;
end $$;

-- 5) Authorized return then resubmit by owner, then approve by reviewer.
do $$
declare
  v jsonb;
  st text;
begin
  v := public.metra_decide_observation(
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    'return_for_correction', 'قيمة غير متسقة');
  if v->>'status' <> 'returned' then
    raise exception 'TEST_FAIL: expected returned, got %', v;
  end if;

  v := public.metra_resubmit_observation(
    '11111111-1111-4111-8111-111111111111',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    '{"dry_temp":"21.0"}'::jsonb);
  if v->>'status' <> 'submitted' then
    raise exception 'TEST_FAIL: expected resubmitted status submitted, got %', v;
  end if;

  select status into st from public.metra_observations
   where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  if st <> 'submitted' then
    raise exception 'TEST_FAIL: observation status after resubmit is %', st;
  end if;

  v := public.metra_decide_observation(
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    'approve', null);
  if v->>'status' <> 'approved' then
    raise exception 'TEST_FAIL: expected approved after resubmit, got %', v;
  end if;
end $$;

-- 6) Non-owner cannot resubmit.
insert into public.metra_observations (
  id, station_id, created_by, observation_type, observed_at, payload,
  status, initial_status, idempotency_key, submitted_at, review_note
) values (
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  'phenomenon', now(), '{}'::jsonb,
  'returned', 'submitted', 'key-3', now(), 'fix values'
) on conflict do nothing;

do $$
declare
  raised boolean := false;
begin
  begin
    perform public.metra_resubmit_observation(
      '22222222-2222-4222-8222-222222222222',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      null);
  exception
    when others then
      if sqlerrm like '%not_observation_owner%' then
        raised := true;
      else
        raise exception 'TEST_FAIL: non-owner resubmit unexpected error: %', sqlerrm;
      end if;
  end;
  if not raised then
    raise exception 'TEST_FAIL: non-owner resubmit was allowed';
  end if;
end $$;

-- 7) Authorized approve of remaining submitted observation.
do $$
declare
  v jsonb;
begin
  v := public.metra_decide_observation(
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    'approve', null);
  if v->>'status' <> 'approved' then
    raise exception 'TEST_FAIL: expected approved, got %', v;
  end if;
end $$;

-- 8) Second decision must fail (already decided).
do $$
declare
  raised boolean := false;
begin
  begin
    perform public.metra_decide_observation(
      '33333333-3333-4333-8333-333333333333',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'approve', null);
  exception
    when others then
      if sqlerrm like '%observation_not_in_submitted_state%' then
        raised := true;
      else
        raise exception 'TEST_FAIL: double decision unexpected error: %', sqlerrm;
      end if;
  end;
  if not raised then
    raise exception 'TEST_FAIL: double decision was allowed';
  end if;
end $$;

-- 9) Audit immutability: UPDATE and DELETE must raise the protection error.
--    Success of the mutation is a hard test failure.
do $$
declare
  raised boolean := false;
  audit_id bigint;
begin
  select id into audit_id
  from public.metra_observation_audit_events
  where observation_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
    and event_type = 'approved'
  limit 1;

  if audit_id is null then
    raise exception 'TEST_FAIL: approved audit event missing';
  end if;

  raised := false;
  begin
    update public.metra_observation_audit_events
       set note = 'tamper'
     where id = audit_id;
    raise exception 'TEST_FAIL: audit UPDATE succeeded';
  exception
    when others then
      if sqlerrm like '%TEST_FAIL:%' then
        raise;
      end if;
      if sqlerrm like '%metra_observation_audit_immutable%' then
        raised := true;
      else
        raise exception 'TEST_FAIL: audit UPDATE unexpected error: %', sqlerrm;
      end if;
  end;
  if not raised then
    raise exception 'TEST_FAIL: audit UPDATE did not raise protection error';
  end if;

  raised := false;
  begin
    delete from public.metra_observation_audit_events where id = audit_id;
    raise exception 'TEST_FAIL: audit DELETE succeeded';
  exception
    when others then
      if sqlerrm like '%TEST_FAIL:%' then
        raise;
      end if;
      if sqlerrm like '%metra_observation_audit_immutable%' then
        raised := true;
      else
        raise exception 'TEST_FAIL: audit DELETE unexpected error: %', sqlerrm;
      end if;
  end;
  if not raised then
    raise exception 'TEST_FAIL: audit DELETE did not raise protection error';
  end if;
end $$;

-- 10) Audit insert failure must roll back observation status change.
insert into public.metra_observations (
  id, station_id, created_by, observation_type, observed_at, payload,
  status, initial_status, idempotency_key, submitted_at
) values (
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  'hourly', now(), '{}'::jsonb,
  'submitted', 'submitted', 'key-4', now()
) on conflict do nothing;

create or replace function public._test_reject_audit_insert()
returns trigger
language plpgsql
as $$
begin
  raise exception 'forced_audit_insert_failure' using errcode = 'P0001';
end;
$$;

drop trigger if exists _test_reject_audit_insert on public.metra_observation_audit_events;
create trigger _test_reject_audit_insert
before insert on public.metra_observation_audit_events
for each row execute function public._test_reject_audit_insert();

do $$
declare
  raised boolean := false;
  st text;
begin
  begin
    perform public.metra_decide_observation(
      '22222222-2222-4222-8222-222222222222',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'ffffffff-ffff-4fff-8fff-ffffffffffff',
      'approve', null);
  exception
    when others then
      if sqlerrm like '%forced_audit_insert_failure%' then
        raised := true;
      else
        raise exception 'TEST_FAIL: audit-failure path unexpected error: %', sqlerrm;
      end if;
  end;
  if not raised then
    raise exception 'TEST_FAIL: decide succeeded despite audit insert failure';
  end if;

  select status into st from public.metra_observations
   where id = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
  if st <> 'submitted' then
    raise exception 'TEST_FAIL: status changed to % despite audit failure (expected submitted)', st;
  end if;
end $$;

drop trigger if exists _test_reject_audit_insert on public.metra_observation_audit_events;
drop function if exists public._test_reject_audit_insert();

do $$ begin raise notice 'OBSERVATION_DECISION_SCENARIOS_PASSED'; end $$;
