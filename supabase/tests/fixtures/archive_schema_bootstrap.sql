-- Disposable PostgreSQL fixture for the archive migration integration test.
-- This file is used only by the GitHub Actions postgres service. It is not a
-- production migration and must never be applied to a hosted METRA database.

do $roles$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end
$roles$;

create schema if not exists auth;
create schema if not exists private;

create or replace function auth.jwt()
returns jsonb
language sql
stable
as $function$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), ''),
    '{}'
  )::jsonb;
$function$;

grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.jwt() to anon, authenticated, service_role;

create table public.metra_account_states (
  user_id uuid primary key,
  account_state text not null
);

create table public.permission_grants (
  user_id uuid not null,
  authority_id uuid not null,
  permission_code text not null,
  approval_status text not null,
  valid_from timestamptz not null,
  valid_to timestamptz,
  revoked_at timestamptz
);

create table public.station_assignments (
  user_id uuid not null,
  authority_id uuid not null,
  station_id uuid not null,
  approval_status text not null,
  valid_from timestamptz not null,
  valid_to timestamptz
);

create table public.station_catalogue (
  id uuid primary key,
  owner_authority_id uuid not null,
  approval_status text not null,
  operational_status text not null
);

create table public.metra_observation_records (
  id uuid primary key,
  station_id uuid,
  source_system text not null,
  source_table text not null,
  source_record_id text not null,
  observation_type text not null,
  observed_at timestamptz,
  payload jsonb not null,
  imported_at timestamptz not null,
  is_demo boolean not null default false
);

create table public.metra_role_permissions (
  role_code text not null,
  permission_code text not null,
  primary key (role_code, permission_code)
);

revoke all on all tables in schema public from anon, authenticated, service_role;
