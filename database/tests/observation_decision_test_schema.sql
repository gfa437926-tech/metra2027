-- Minimal schema stubs required before applying the real decision migration.
-- Temporary test database only. Never points at Supabase or production.

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key
);

create table if not exists public.station_catalogue (
  id uuid primary key,
  name text not null default 'test'
);

create table if not exists public._test_station_permissions (
  user_id uuid not null,
  station_id uuid not null,
  permission_code text not null,
  primary key (user_id, station_id, permission_code)
);

create or replace function public.metra_user_has_station_permission(
  p_user_id uuid,
  p_station_id uuid,
  p_permission_code text
) returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public._test_station_permissions
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

-- Production audit immutability trigger (from operational observation migration).
create or replace function public.reject_metra_observation_audit_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'metra_observation_audit_immutable' using errcode = '42501';
end;
$$;

drop trigger if exists metra_observation_audit_immutable on public.metra_observation_audit_events;
create trigger metra_observation_audit_immutable
before update or delete on public.metra_observation_audit_events
for each row execute function public.reject_metra_observation_audit_mutation();

-- Placeholder roles referenced by the production migration grants.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'metra_api_runtime') then
    create role metra_api_runtime nologin;
  end if;
end $$;
