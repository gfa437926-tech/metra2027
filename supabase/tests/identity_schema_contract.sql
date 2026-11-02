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
end $$;

select
  (select count(*) from public.metra_account_states) as account_states,
  (select count(*) from public.authority_memberships) as authority_memberships,
  (select count(*) from public.station_assignments) as station_assignments,
  (select count(*) from public.permission_grants) as permission_grants;
