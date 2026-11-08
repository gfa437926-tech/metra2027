-- Isolated PostgreSQL scenarios for equipment faults + session RLS.
-- Run against metra_ops_test after migrations. Does not touch legacy DB.

\set ON_ERROR_STOP on

do $$
declare
  station_a uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  station_b uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  user_a uuid := '11111111-1111-1111-1111-111111111111';
  user_b uuid := '22222222-2222-2222-2222-222222222222';
  fault_a uuid;
  fault_b uuid;
  seen int;
begin
  insert into auth.users(id, email) values (user_a, 'a@test'), (user_b, 'b@test')
  on conflict (id) do nothing;
  insert into public.station_catalogue(id, code, name)
  values (station_a, 'STA', 'Station A'), (station_b, 'STB', 'Station B')
  on conflict (id) do nothing;

  -- Seed as table owner/bypass before switching to constrained role in later blocks.
  insert into public.metra_equipment_faults (
    id, station_id, reporter_user_id, equipment_category, equipment_name, description,
    severity, status, is_operationally_blocking, occurred_at, progress_percent)
  values (
    gen_random_uuid(), station_a, user_a, 'Sensors', 'Temp Probe',
    'Probe offline for more than ten minutes', 'High', 'Submitted', true, now(), 0)
  returning id into fault_a;

  insert into public.metra_equipment_faults (
    id, station_id, reporter_user_id, equipment_category, equipment_name, description,
    severity, status, is_operationally_blocking, occurred_at, progress_percent)
  values (
    gen_random_uuid(), station_b, user_b, 'Sensors', 'Wind Sensor',
    'Wind sensor not reporting values', 'Medium', 'Submitted', false, now(), 0)
  returning id into fault_b;

  -- Station A context must not see station B fault.
  perform set_config('app.station_id', station_a::text, false);
  set local role metra_ops_faults;
  select count(*) into seen from public.metra_equipment_faults where id = fault_b;
  if seen <> 0 then
    raise exception 'TEST_FAIL: station isolation leaked fault_b into station_a context';
  end if;
  select count(*) into seen from public.metra_equipment_faults where id = fault_a;
  if seen <> 1 then
    raise exception 'TEST_FAIL: station_a cannot read its own fault under ops role';
  end if;
  reset role;

  -- Cross-station update attempt must affect 0 rows under station_a context.
  perform set_config('app.station_id', station_a::text, false);
  set local role metra_ops_faults;
  update public.metra_equipment_faults set status = 'UnderReview' where id = fault_b;
  get diagnostics seen = row_count;
  if seen <> 0 then
    raise exception 'TEST_FAIL: IDOR update on foreign station succeeded';
  end if;
  reset role;

  raise notice 'equipment_fault_npgsql_isolation: PASS';
end $$;

-- Audit immutability: UPDATE/DELETE must fail with expected protection error.
do $$
declare
  fault_id uuid;
  station uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  actor uuid := '11111111-1111-1111-1111-111111111111';
  audit_id bigint;
begin
  select id into fault_id from public.metra_equipment_faults where station_id = station limit 1;
  insert into public.metra_equipment_fault_audit_events (
    fault_id, station_id, actor_user_id, event_type, from_status, to_status, note)
  values (fault_id, station, actor, 'test_seed', null, 'Submitted', 'seed')
  returning id into audit_id;

  begin
    update public.metra_equipment_fault_audit_events set note = 'tamper' where id = audit_id;
    raise exception 'TEST_FAIL: audit UPDATE succeeded';
  exception
    when insufficient_privilege then null;
    when raise_exception then
      if sqlerrm like 'TEST_FAIL%' then raise;
      end if;
      -- expected protection exception from trigger
      null;
  end;

  begin
    delete from public.metra_equipment_fault_audit_events where id = audit_id;
    raise exception 'TEST_FAIL: audit DELETE succeeded';
  exception
    when insufficient_privilege then null;
    when raise_exception then
      if sqlerrm like 'TEST_FAIL%' then raise;
      end if;
      null;
  end;

  raise notice 'equipment_fault_audit_immutability: PASS';
end $$;
