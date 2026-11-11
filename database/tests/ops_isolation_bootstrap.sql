-- Test-only bootstrap for a disposable PostgreSQL service in CI.
-- Never run against hosted or legacy databases.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create role metra_ops_faults nologin;
create role metra_api_runtime nologin;
create schema auth;
create table auth.users (id uuid primary key, email text);
create table public.station_catalogue (
 id uuid primary key, code text not null unique, name text not null
);
-- Minimal, explicit permission fixture. The test helper is data-driven rather
-- than an always-true stub, so denied actors/assignees fail closed.
create table public.metra_test_station_permissions (
 user_id uuid not null references auth.users(id),
 station_id uuid not null references public.station_catalogue(id),
 permission_code text not null,
 primary key (user_id, station_id, permission_code)
);
create or replace function public.metra_user_has_station_permission(
 p_user_id uuid, p_station_id uuid, p_permission text
) returns boolean
language sql stable security definer
set search_path = pg_catalog, public
as $$
 select exists (
   select 1
   from public.metra_test_station_permissions p
   where p.user_id = p_user_id
     and p.station_id = p_station_id
     and p.permission_code = p_permission
 )
$$;
