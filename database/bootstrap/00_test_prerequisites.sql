-- Prerequisites for applying NEW METRA migrations on an isolated test database.
-- Does not touch the legacy INSERT database.

create extension if not exists pgcrypto;
create extension if not exists "uuid-ossp";

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  role text default 'authenticated'
);

create table if not exists public.station_catalogue (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  name text not null,
  station_type text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Minimal permission helpers used by security-definer RPCs in migrations.
create or replace function public.metra_user_has_station_permission(
  p_user_id uuid,
  p_station_id uuid,
  p_permission text
) returns boolean
language plpgsql
stable
as $$
begin
  -- Test harness: allow when a grant row exists; production migrations may replace this.
  return exists (
    select 1
    from public.metra_station_permission_grants g
    where g.user_id = p_user_id
      and g.station_id = p_station_id
      and g.permission_code = p_permission
      and g.is_active
  );
exception
  when undefined_table then
    -- Before grants table exists, deny by default.
    return false;
end;
$$;

create table if not exists public.metra_station_permission_grants (
  user_id uuid not null,
  station_id uuid not null references public.station_catalogue(id),
  permission_code text not null,
  is_active boolean not null default true,
  primary key (user_id, station_id, permission_code)
);

-- Roles expected by Supabase-oriented migrations
do $$
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
  if not exists (select 1 from pg_roles where rolname = 'metra_api_runtime') then
    create role metra_api_runtime nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'metra_ops_faults') then
    create role metra_ops_faults nologin;
  end if;
end $$;
