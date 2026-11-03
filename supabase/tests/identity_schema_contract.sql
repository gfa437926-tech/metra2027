-- Read-only structural regression checks for the deployed METRA identity schema.
-- Safe to run against the target project: no rows are inserted or changed.
do $$
declare
  v_missing text;
begin
  select string_agg(t.table_name, ', ')
    into v_missing
  from (values
    ('metra_account_states'),
    ('authority_memberships'),
    ('station_assignments'),
    ('permission_grants')
  ) as t(table_name)
  where not exists (
    select 1 from information_schema.tables i
    where i.table_schema = 'public' and i.table_name = t.table_name
  );
  if v_missing is not null then
    raise exception 'Missing identity tables: %', v_missing;
  end if;

  if exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('metra_account_states','authority_memberships','station_assignments','permission_grants')
      and not c.relrowsecurity
  ) then
    raise exception 'RLS is not enabled on every identity table';
  end if;

  if exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename in ('metra_account_states','authority_memberships','station_assignments','permission_grants')
      and policyname not like '%deny_clients%'
  ) then
    raise exception 'Unexpected identity policy exists';
  end if;

  if exists (
    select 1 from (values
      ('authority_memberships','authority_memberships_no_overlapping_periods'),
      ('station_assignments','station_assignments_no_overlapping_periods'),
      ('permission_grants','permission_grants_no_overlapping_periods'),
      ('station_catalogue','station_catalogue_id_owner_authority_unique')
    ) expected(table_name,constraint_name)
    where not exists (
      select 1 from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
      where n.nspname='public'
        and t.relname=expected.table_name
        and c.conname=expected.constraint_name
    )
  ) then
    raise exception 'An expected identity integrity constraint is missing';
  end if;

  if not exists (
    select 1 from pg_roles
    where rolname='metra_api_runtime'
      and rolcanlogin=false and rolsuper=false and rolbypassrls=false
  ) then
    raise exception 'The dedicated API runtime role is missing or over-privileged';
  end if;

  if not has_schema_privilege('metra_api_runtime','private','USAGE') then
    raise exception 'The API runtime role cannot use the private RPC schema';
  end if;

  if has_schema_privilege('anon','private','USAGE')
     or has_schema_privilege('authenticated','private','USAGE')
     or has_schema_privilege('service_role','private','USAGE') then
    raise exception 'A client or service role can access the private RPC schema';
  end if;

  if not has_function_privilege(
       'metra_api_runtime',
       'private.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text)',
       'EXECUTE')
     or not has_function_privilege(
       'metra_api_runtime',
       'private.decide_metra_registration(uuid,text,uuid,text,text,timestamptz)',
       'EXECUTE') then
    raise exception 'The API runtime role lacks a required private RPC grant';
  end if;

  if has_function_privilege(
       'anon',
       'private.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text)',
       'EXECUTE')
     or has_function_privilege(
       'authenticated',
       'private.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text)',
       'EXECUTE')
     or has_function_privilege(
       'service_role',
       'private.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text)',
       'EXECUTE')
     or has_function_privilege(
       'anon',
       'private.decide_metra_registration(uuid,text,uuid,text,text,timestamptz)',
       'EXECUTE')
     or has_function_privilege(
       'authenticated',
       'private.decide_metra_registration(uuid,text,uuid,text,text,timestamptz)',
       'EXECUTE')
     or has_function_privilege(
       'service_role',
       'private.decide_metra_registration(uuid,text,uuid,text,text,timestamptz)',
       'EXECUTE') then
    raise exception 'A client or service role can execute a private registration RPC';
  end if;

  if (
    select count(*) from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='private'
      and p.proname='decide_metra_registration'
      and pg_get_function_identity_arguments(p.oid) =
        'p_request_id uuid, p_expected_status text, p_actor_user_id uuid, p_decision text, p_note text, p_occurred_at timestamp with time zone'
  ) <> 1 then
    raise exception 'The expected-state approval RPC overload is missing or duplicated';
  end if;
end $;

select
  (select count(*) from public.metra_account_states) as account_states,
  (select count(*) from public.authority_memberships) as authority_memberships,
  (select count(*) from public.station_assignments) as station_assignments,
  (select count(*) from public.permission_grants) as permission_grants;
