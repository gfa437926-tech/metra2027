-- End-to-end authorization and station-isolation checks for the proposed
-- archive RPC migration. Runs only against the disposable GitHub Actions DB.

insert into public.metra_account_states (user_id, account_state) values
  ('33333333-3333-4333-8333-333333333333', 'active'),
  ('44444444-4444-4444-8444-444444444444', 'active'),
  ('55555555-5555-4555-8555-555555555555', 'disabled'),
  ('66666666-6666-4666-8666-666666666666', 'active'),
  ('77777777-7777-4777-8777-777777777777', 'active'),
  ('88888888-8888-4888-8888-888888888888', 'active');

insert into public.station_catalogue (id, owner_authority_id, approval_status, operational_status) values
  ('11111111-1111-4111-8111-111111111111', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'approved', 'active'),
  ('22222222-2222-4222-8222-222222222222', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'approved', 'active');

insert into public.permission_grants
  (user_id, authority_id, permission_code, approval_status, valid_from, valid_to, revoked_at)
values
  ('33333333-3333-4333-8333-333333333333', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.archive.read', 'approved', now() - interval '1 day', null, null),
  ('55555555-5555-4555-8555-555555555555', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.archive.read', 'approved', now() - interval '1 day', null, null),
  ('66666666-6666-4666-8666-666666666666', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.archive.read', 'approved', now() - interval '2 days', now() - interval '1 day', null),
  ('77777777-7777-4777-8777-777777777777', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.archive.read', 'approved', now() - interval '1 day', null, null),
  ('88888888-8888-4888-8888-888888888888', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'observation.archive.read', 'approved', now() - interval '1 day', null, now() - interval '1 hour');

insert into public.station_assignments
  (user_id, authority_id, station_id, approval_status, valid_from, valid_to)
values
  ('33333333-3333-4333-8333-333333333333', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'approved', now() - interval '1 day', null),
  ('44444444-4444-4444-8444-444444444444', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'approved', now() - interval '1 day', null),
  ('55555555-5555-4555-8555-555555555555', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'approved', now() - interval '1 day', null),
  ('66666666-6666-4666-8666-666666666666', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'approved', now() - interval '1 day', null),
  ('77777777-7777-4777-8777-777777777777', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'approved', now() - interval '2 days', now() - interval '1 day'),
  ('88888888-8888-4888-8888-888888888888', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'approved', now() - interval '1 day', null);

insert into public.metra_observation_records
  (id, station_id, source_system, source_table, source_record_id, observation_type, observed_at, payload, imported_at, is_demo)
values
  ('99999999-9999-4999-8999-999999999991', '11111111-1111-4111-8111-111111111111', 'fixture', 'hourly', 's1', 'hourly', now() - interval '2 hours', '{"temperature": 21}', now(), false),
  ('99999999-9999-4999-8999-999999999992', '22222222-2222-4222-8222-222222222222', 'fixture', 'hourly', 's2', 'hourly', now() - interval '2 hours', '{"temperature": 99}', now(), false),
  ('99999999-9999-4999-8999-999999999993', null, 'fixture', 'hourly', 'unlinked', 'hourly', now() - interval '2 hours', '{"temperature": 88}', now(), false),
  ('99999999-9999-4999-8999-999999999994', '11111111-1111-4111-8111-111111111111', 'fixture', 'hourly', 'demo', 'hourly', now() - interval '2 hours', '{"temperature": 77}', now(), true),
  ('99999999-9999-4999-8999-999999999995', '11111111-1111-4111-8111-111111111111', 'fixture', 'hourly', 's1-older', 'hourly', now() - interval '3 hours', '{"temperature": 19}', now(), false);

set "request.jwt.claims" = '{"role":"service_role"}';
set role service_role;

do $tests$
declare
  v_page jsonb;
  v_detail jsonb;
begin
  v_page := public.metra_station_observation_archive_page(
    '33333333-3333-4333-8333-333333333333',
    '11111111-1111-4111-8111-111111111111',
    null, null, null, 50, 0
  );
  if v_page ->> 'authorized' <> 'true' then
    raise exception 'active explicitly-granted station member should be authorized';
  end if;
  if jsonb_array_length(v_page -> 'items') <> 2 then
    raise exception 'station archive must return exactly two non-demo linked records';
  end if;
  if v_page #>> '{items,0,payload,temperature}' <> '21' then
    raise exception 'station archive returned a foreign, unlinked or demo record';
  end if;
  if v_page #>> '{page,hasMore}' <> 'false' then
    raise exception 'hasMore must be false for a complete two-row fixture page';
  end if;

  v_page := public.metra_station_observation_archive_page(
    '33333333-3333-4333-8333-333333333333',
    '11111111-1111-4111-8111-111111111111',
    'hourly', null, null, 1, 0
  );
  if jsonb_array_length(v_page -> 'items') <> 1
     or v_page #>> '{page,hasMore}' <> 'true' then
    raise exception 'bounded pagination must return one item and hasMore=true';
  end if;

  v_page := public.metra_station_observation_archive_page(
    '33333333-3333-4333-8333-333333333333',
    '11111111-1111-4111-8111-111111111111',
    null, now() - interval '1 hour', now(), 50, 0
  );
  if jsonb_array_length(v_page -> 'items') <> 0
     or v_page #>> '{page,hasMore}' <> 'false' then
    raise exception 'UTC period filter must exclude records outside the requested range';
  end if;

  v_page := public.metra_station_observation_archive_page(
    '33333333-3333-4333-8333-333333333333',
    '22222222-2222-4222-8222-222222222222',
    null, null, null, 50, 0
  );
  if v_page ->> 'authorized' <> 'false' then
    raise exception 'station assignment must not authorize a different station';
  end if;

  v_detail := public.metra_station_observation_archive_detail(
    '33333333-3333-4333-8333-333333333333',
    '22222222-2222-4222-8222-222222222222',
    '99999999-9999-4999-8999-999999999992'
  );
  if v_detail ->> 'authorized' <> 'false' then
    raise exception 'detail must deny a record belonging to another station';
  end if;

  v_page := public.metra_station_observation_archive_page(
    '44444444-4444-4444-8444-444444444444',
    '11111111-1111-4111-8111-111111111111',
    null, null, null, 50, 0
  );
  if v_page ->> 'authorized' <> 'false' then
    raise exception 'station assignment alone must not grant archive permission';
  end if;

  v_page := public.metra_station_observation_archive_page(
    '55555555-5555-4555-8555-555555555555',
    '11111111-1111-4111-8111-111111111111',
    null, null, null, 50, 0
  );
  if v_page ->> 'authorized' <> 'false' then
    raise exception 'inactive account must be denied';
  end if;

  v_page := public.metra_station_observation_archive_page(
    '66666666-6666-4666-8666-666666666666',
    '11111111-1111-4111-8111-111111111111',
    null, null, null, 50, 0
  );
  if v_page ->> 'authorized' <> 'false' then
    raise exception 'expired individual permission grant must be denied';
  end if;

  v_page := public.metra_station_observation_archive_page(
    '77777777-7777-4777-8777-777777777777',
    '11111111-1111-4111-8111-111111111111',
    null, null, null, 50, 0
  );
  if v_page ->> 'authorized' <> 'false' then
    raise exception 'expired station assignment must be denied';
  end if;

  v_page := public.metra_station_observation_archive_page(
    '88888888-8888-4888-8888-888888888888',
    '11111111-1111-4111-8111-111111111111',
    null, null, null, 50, 0
  );
  if v_page ->> 'authorized' <> 'false' then
    raise exception 'revoked individual permission grant must be denied';
  end if;
end
$tests$;

reset role;

reset role;

set role anon;
do $anon_denial$
begin
  begin
    perform public.metra_station_observation_archive_page(
      '33333333-3333-4333-8333-333333333333',
      '11111111-1111-4111-8111-111111111111',
      null, null, null, 50, 0
    );
    raise exception 'anon unexpectedly executed archive RPC';
  exception when insufficient_privilege then
    null;
  end;
end
$anon_denial$;
reset role;

set role authenticated;
do $authenticated_denial$
begin
  begin
    perform public.metra_station_observation_archive_detail(
      '33333333-3333-4333-8333-333333333333',
      '11111111-1111-4111-8111-111111111111',
      '99999999-9999-4999-8999-999999999991'
    );
    raise exception 'authenticated unexpectedly executed archive RPC';
  exception when insufficient_privilege then
    null;
  end;
end
$authenticated_denial$;
reset role;

do $no_auto_grant$
begin
  if exists (select 1 from public.metra_role_permissions where permission_code = 'observation.archive.read') then
    raise exception 'role permission matrix must not auto-assign archive read';
  end if;
  if (select count(*) from public.permission_grants where permission_code = 'observation.archive.read') <> 5 then
    raise exception 'fixture should contain only explicit individual test grants';
  end if;
end
$no_auto_grant$;
