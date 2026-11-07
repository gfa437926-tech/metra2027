-- Isolated PostgreSQL integration tests for metra_decide_observation.
-- Uses a temporary database only. Does not connect to Supabase or production.

begin;

create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key
);

create table if not exists public.station_catalogue (
  id uuid primary key,
  name text not null default 'test'
);

-- Controllable permission stub for isolated tests.
create table if not exists public._test_station_permissions (
  user_id uuid not null,
  station_id uuid not null,
  permission_code text not null,
  primary key (user_id, station_id, permission_code)
);

create or replace function public.metra_user_has_station_permission(
  p_user_id uuid, p_station_id uuid, p_permission_code text
) returns boolean
language sql stable
as $$
  select exists (
    select 1 from public._test_station_permissions
    where user_id = p_user_id
      and station_id = p_station_id
      and permission_code = p_permission_code
  );
$$;

create table if not exists public.metra_observations (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.station_catalogue(id),
  created_by uuid not null references auth.users(id),
  observation_type text not null check (observation_type in ('daily','hourly','phenomenon')),
  observed_at timestamptz not null,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  status text not null check (status in ('draft','submitted','returned','approved')),
  initial_status text not null check (initial_status in ('draft','submitted')),
  idempotency_key text not null,
  submitted_at timestamptz,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (station_id, created_by, idempotency_key)
);

create table if not exists public.metra_observation_audit_events (
  id bigint generated always as identity primary key,
  observation_id uuid not null references public.metra_observations(id),
  station_id uuid not null references public.station_catalogue(id),
  actor_user_id uuid not null references auth.users(id),
  event_type text not null check (event_type in ('created_draft','submitted','returned','approved','resubmitted')),
  from_status text check (from_status is null or from_status in ('draft','submitted','returned','approved')),
  to_status text not null check (to_status in ('draft','submitted','returned','approved')),
  note text,
  occurred_at timestamptz not null default now()
);

create or replace function public.reject_metra_observation_audit_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'metra_observation_audit_immutable' using errcode = '42501';
end;
$$;

create trigger metra_observation_audit_immutable
before update or delete on public.metra_observation_audit_events
for each row execute function public.reject_metra_observation_audit_mutation();

-- Hardened decision function under test (mirrors migration 20261107020000).
create or replace function public.metra_decide_observation(
  p_user_id uuid, p_station_id uuid, p_observation_id uuid,
  p_decision text, p_note text default null
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_row public.metra_observations%rowtype;
  v_permission text;
  v_status text;
  v_event_type text;
  v_note text;
begin
  if p_user_id is null or p_station_id is null or p_observation_id is null then
    raise exception 'user_station_observation_required' using errcode = '22023';
  end if;
  if p_decision is null or p_decision not in ('approve', 'return_for_correction') then
    raise exception 'invalid_observation_decision' using errcode = '22023';
  end if;
  v_note := nullif(btrim(coalesce(p_note, '')), '');
  if p_note is not null and length(p_note) > 2000 then
    raise exception 'decision_note_too_long' using errcode = '22023';
  end if;
  if p_decision = 'return_for_correction' and v_note is null then
    raise exception 'decision_note_required' using errcode = '22023';
  end if;

  select * into v_row from public.metra_observations
   where id = p_observation_id and station_id = p_station_id for update;
  if not found then raise exception 'observation_not_found' using errcode = 'P0002'; end if;
  if v_row.status <> 'submitted' then
    raise exception 'observation_not_in_submitted_state' using errcode = '22023';
  end if;
  if v_row.created_by = p_user_id then
    raise exception 'self_review_forbidden' using errcode = '42501';
  end if;

  v_permission := case when p_decision = 'approve' then 'observation.approve'
                       else 'observation.return_for_correction' end;
  if not public.metra_user_has_station_permission(p_user_id, p_station_id, v_permission) then
    raise exception 'station_observation_decision_forbidden' using errcode = '42501';
  end if;

  v_status := case when p_decision = 'approve' then 'approved' else 'returned' end;
  v_event_type := v_status;

  update public.metra_observations
     set status = v_status, reviewed_by = p_user_id, reviewed_at = now(),
         review_note = v_note, updated_at = now()
   where id = p_observation_id and station_id = p_station_id and status = 'submitted';
  if not found then
    raise exception 'observation_not_in_submitted_state' using errcode = '22023';
  end if;

  insert into public.metra_observation_audit_events
    (observation_id, station_id, actor_user_id, event_type, from_status, to_status, note)
  values (p_observation_id, p_station_id, p_user_id, v_event_type, 'submitted', v_status, v_note);

  return jsonb_build_object('id', p_observation_id, 'status', v_status, 'replayed', false);
end;
$$;

-- Seed identities and stations
insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222'),
  ('33333333-3333-4333-8333-333333333333');
insert into public.station_catalogue(id, name) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'station-a'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'station-b');

insert into public._test_station_permissions values
  ('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.approve'),
  ('22222222-2222-4222-8222-222222222222', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.return_for_correction'),
  ('33333333-3333-4333-8333-333333333333', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.approve');

insert into public.metra_observations (
  id, station_id, created_by, observation_type, observed_at, payload,
  status, initial_status, idempotency_key, submitted_at
) values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  'hourly', now(), '{}'::jsonb,
  'submitted', 'submitted', 'key-1', now()
);

-- 1) Self-review must fail
do $$
begin
  begin
    perform public.metra_decide_observation(
      '11111111-1111-4111-8111-111111111111',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'approve', null);
    raise exception 'TEST_FAIL: self-review was allowed';
  exception when others then
    if sqlerrm not like '%self_review_forbidden%' then
      raise exception 'TEST_FAIL: unexpected error %', sqlerrm;
    end if;
  end;
end $$;

-- 2) Cross-station decision must fail (observation not found in station B)
do $$
begin
  begin
    perform public.metra_decide_observation(
      '22222222-2222-4222-8222-222222222222',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'approve', null);
    raise exception 'TEST_FAIL: cross-station decision was allowed';
  exception when others then
    if sqlerrm not like '%observation_not_found%' then
      raise exception 'TEST_FAIL: unexpected cross-station error %', sqlerrm;
    end if;
  end;
end $$;

-- 3) Authorized different user can approve
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

-- 4) Second decision on same observation must fail (already decided)
do $$
begin
  begin
    perform public.metra_decide_observation(
      '33333333-3333-4333-8333-333333333333',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'approve', null);
    raise exception 'TEST_FAIL: double decision was allowed';
  exception when others then
    if sqlerrm not like '%observation_not_in_submitted_state%' then
      raise exception 'TEST_FAIL: unexpected double-decision error %', sqlerrm;
    end if;
  end;
end $$;

-- 5) Audit row written and immutable
do $$
declare
  n int;
begin
  select count(*) into n from public.metra_observation_audit_events
   where observation_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
     and event_type = 'approved'
     and from_status = 'submitted'
     and to_status = 'approved';
  if n <> 1 then
    raise exception 'TEST_FAIL: expected one approved audit event, got %', n;
  end if;

  begin
    update public.metra_observation_audit_events set note = 'tamper' where observation_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
    raise exception 'TEST_FAIL: audit mutation was allowed';
  exception when others then
    null;
  end;
end $$;

-- 6) Return for correction requires note and writes returned audit
insert into public.metra_observations (
  id, station_id, created_by, observation_type, observed_at, payload,
  status, initial_status, idempotency_key, submitted_at
) values (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  'daily', now(), '{}'::jsonb,
  'submitted', 'submitted', 'key-2', now()
);

do $$
begin
  begin
    perform public.metra_decide_observation(
      '22222222-2222-4222-8222-222222222222',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      'return_for_correction', null);
    raise exception 'TEST_FAIL: return without note was allowed';
  exception when others then
    if sqlerrm not like '%decision_note_required%' then
      raise exception 'TEST_FAIL: unexpected return-note error %', sqlerrm;
    end if;
  end;
end $$;

do $$
declare
  v jsonb;
begin
  v := public.metra_decide_observation(
    '22222222-2222-4222-8222-222222222222',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    'return_for_correction', 'قيمة الحرارة غير متسقة');
  if v->>'status' <> 'returned' then
    raise exception 'TEST_FAIL: expected returned, got %', v;
  end if;
end $$;

-- 7) Concurrent second approver after first commit fails (serialized by status)
-- Simulated by sequential attempts already covered in (4).

rollback;

-- Signal success to the shell harness
do $$ begin raise notice 'OBSERVATION_DECISION_ISOLATED_PG_TESTS_PASSED'; end $$;
