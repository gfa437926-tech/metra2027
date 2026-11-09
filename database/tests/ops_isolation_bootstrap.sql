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
create or replace function public.metra_user_has_station_permission(
 p_user_id uuid, p_station_id uuid, p_permission text
) returns boolean language sql stable as $$ select true $$;
