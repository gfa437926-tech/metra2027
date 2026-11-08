-- METRA Equipment Faults: additive, station-scoped persistence.
-- Target: Supabase project tbdnklyxjvbrilvnwgmq only.
-- This migration creates new objects only. It does not alter or delete existing rows.
-- Runtime login password MUST be provisioned out-of-band through the secret manager.

begin;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'metra_equipment_faults_runtime') then
    create role metra_equipment_faults_runtime nologin noinherit nosuperuser nobypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'metra_equipment_faults_login') then
    create role metra_equipment_faults_login login noinherit nosuperuser nobypassrls;
  end if;
end
$$;

-- The login can SET ROLE to this feature-specific NOLOGIN role, but does not
-- inherit its permissions implicitly. Do not add this login to service_role.
grant metra_equipment_faults_runtime to metra_equipment_faults_login
  with inherit false, set true;

create table public.equipment_faults (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.station_catalogue(id) on delete restrict,
  reporter_id uuid not null references auth.users(id) on delete restrict,
  equipment_category text not null,
  equipment_name text not null,
  description text not null,
  severity text not null,
  status text not null default 'Submitted',
  occurred_at timestamptz not null,
  is_operationally_blocking boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  constraint equipment_faults_id_station_unique unique (id, station_id),
  constraint equipment_faults_category_length check (
    equipment_category = btrim(equipment_category)
    and char_length(equipment_category) between 2 and 80
  ),
  constraint equipment_faults_name_length check (
    equipment_name = btrim(equipment_name)
    and char_length(equipment_name) between 2 and 120
  ),
  constraint equipment_faults_description_length check (
    description = btrim(description)
    and char_length(description) between 10 and 4000
  ),
  constraint equipment_faults_severity_check check (
    severity in ('Low', 'Medium', 'High', 'Critical')
  ),
  constraint equipment_faults_status_check check (
    status in ('Submitted', 'UnderReview', 'Assigned', 'InProgress', 'Resolved', 'Closed', 'Rejected')
  ),
  constraint equipment_faults_blocking_severity_check check (
    not is_operationally_blocking or severity in ('High', 'Critical')
  ),
  constraint equipment_faults_version_positive check (version > 0)
);

create table public.equipment_fault_audit (
  id bigint generated always as identity primary key,
  fault_id uuid not null,
  station_id uuid not null references public.station_catalogue(id) on delete restrict,
  actor_id uuid not null references auth.users(id) on delete restrict,
  previous_status text null,
  new_status text not null,
  reason text not null,
  occurred_at timestamptz not null default now(),
  constraint equipment_fault_audit_fault_station_fk
    foreign key (fault_id, station_id)
    references public.equipment_faults(id, station_id) on delete restrict,
  constraint equipment_fault_audit_previous_status_check check (
    previous_status is null or previous_status in
      ('Submitted', 'UnderReview', 'Assigned', 'InProgress', 'Resolved', 'Closed', 'Rejected')
  ),
  constraint equipment_fault_audit_new_status_check check (
    new_status in ('Submitted', 'UnderReview', 'Assigned', 'InProgress', 'Resolved', 'Closed', 'Rejected')
  ),
  constraint equipment_fault_audit_reason_length check (
    reason = btrim(reason) and char_length(reason) between 5 and 1000
  ),
  constraint equipment_fault_audit_creation_state_check check (
    previous_status is not null or new_status = 'Submitted'
  )
);

create index equipment_faults_station_created_idx
  on public.equipment_faults (station_id, created_at desc, id desc);
create index equipment_faults_station_status_created_idx
  on public.equipment_faults (station_id, status, created_at desc, id desc);
create index equipment_fault_audit_fault_time_idx
  on public.equipment_fault_audit (fault_id, occurred_at, id);

create or replace function public.equipment_faults_guard_write()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid;
  v_station uuid;
  v_reason text;
  v_allowed boolean := false;
begin
  v_actor := nullif(current_setting('metra.actor_id', true), '')::uuid;
  v_station := nullif(current_setting('metra.station_id', true), '')::uuid;
  v_reason := nullif(current_setting('metra.reason', true), '');

  if v_actor is null or v_station is null or v_reason is null
     or char_length(v_reason) < 5 or char_length(v_reason) > 1000
     or v_reason <> btrim(v_reason) then
    raise exception 'equipment_fault_context_required' using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'Submitted'
       or new.reporter_id <> v_actor
       or new.station_id <> v_station then
      raise exception 'equipment_fault_create_context_mismatch' using errcode = '42501';
    end if;
    return new;
  end if;

  if new.station_id <> old.station_id or new.reporter_id <> old.reporter_id
     or new.id <> old.id then
    raise exception 'equipment_fault_identity_immutable' using errcode = '42501';
  end if;

  if new.status is distinct from old.status then
    v_allowed :=
      (old.status = 'Submitted' and new.status in ('UnderReview', 'Rejected'))
      or (old.status = 'UnderReview' and new.status in ('Assigned', 'Rejected'))
      or (old.status = 'Assigned' and new.status in ('UnderReview', 'InProgress'))
      or (old.status = 'InProgress' and new.status = 'Resolved')
      or (old.status = 'Resolved' and new.status in ('InProgress', 'Closed'));
    if not v_allowed then
      raise exception 'equipment_fault_transition_not_allowed' using errcode = '23514';
    end if;
    if v_station <> old.station_id then
      raise exception 'equipment_fault_station_context_mismatch' using errcode = '42501';
    end if;
    new.updated_at := now();
    new.version := old.version + 1;
  end if;
  return new;
end;
$$;

create or replace function public.equipment_faults_append_audit()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid;
  v_reason text;
begin
  v_actor := nullif(current_setting('metra.actor_id', true), '')::uuid;
  v_reason := nullif(current_setting('metra.reason', true), '');
  if v_actor is null or v_reason is null then
    raise exception 'equipment_fault_audit_context_required' using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    insert into public.equipment_fault_audit
      (fault_id, station_id, actor_id, previous_status, new_status, reason)
    values
      (new.id, new.station_id, v_actor, null, new.status, v_reason);
  elsif new.status is distinct from old.status then
    insert into public.equipment_fault_audit
      (fault_id, station_id, actor_id, previous_status, new_status, reason)
    values
      (new.id, new.station_id, v_actor, old.status, new.status, v_reason);
  end if;
  return new;
end;
$$;

create or replace function public.equipment_fault_audit_reject_mutation()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  raise exception 'equipment_fault_audit_is_append_only' using errcode = '42501';
end;
$$;

create trigger equipment_faults_guard_write
before insert or update on public.equipment_faults
for each row execute function public.equipment_faults_guard_write();

create trigger equipment_faults_append_audit
after insert or update of status on public.equipment_faults
for each row execute function public.equipment_faults_append_audit();

create trigger equipment_fault_audit_immutable
before update or delete on public.equipment_fault_audit
for each row execute function public.equipment_fault_audit_reject_mutation();

alter table public.equipment_faults enable row level security;
alter table public.equipment_faults force row level security;
alter table public.equipment_fault_audit enable row level security;
alter table public.equipment_fault_audit force row level security;

create policy equipment_faults_runtime_select
  on public.equipment_faults for select to metra_equipment_faults_runtime
  using (
    station_id = nullif(current_setting('metra.station_id', true), '')::uuid
    and nullif(current_setting('metra.actor_id', true), '') is not null
  );

create policy equipment_faults_runtime_insert
  on public.equipment_faults for insert to metra_equipment_faults_runtime
  with check (
    station_id = nullif(current_setting('metra.station_id', true), '')::uuid
    and reporter_id = nullif(current_setting('metra.actor_id', true), '')::uuid
  );

create policy equipment_faults_runtime_update
  on public.equipment_faults for update to metra_equipment_faults_runtime
  using (
    station_id = nullif(current_setting('metra.station_id', true), '')::uuid
    and nullif(current_setting('metra.actor_id', true), '') is not null
  )
  with check (
    station_id = nullif(current_setting('metra.station_id', true), '')::uuid
    and nullif(current_setting('metra.actor_id', true), '') is not null
  );

create policy equipment_fault_audit_runtime_insert
  on public.equipment_fault_audit for insert to metra_equipment_faults_runtime
  with check (
    station_id = nullif(current_setting('metra.station_id', true), '')::uuid
    and actor_id = nullif(current_setting('metra.actor_id', true), '')::uuid
  );

create policy equipment_faults_deny_clients
  on public.equipment_faults for all to anon, authenticated
  using (false) with check (false);

create policy equipment_fault_audit_deny_clients
  on public.equipment_fault_audit for all to anon, authenticated
  using (false) with check (false);

grant usage on schema public to metra_equipment_faults_runtime;
grant select on public.equipment_faults to metra_equipment_faults_runtime;
grant insert (station_id, reporter_id, equipment_category, equipment_name, description,
              severity, status, occurred_at, is_operationally_blocking)
  on public.equipment_faults to metra_equipment_faults_runtime;
grant update (status) on public.equipment_faults to metra_equipment_faults_runtime;
grant insert on public.equipment_fault_audit to metra_equipment_faults_runtime;
grant usage, select on sequence public.equipment_fault_audit_id_seq
  to metra_equipment_faults_runtime;

revoke all on public.equipment_faults, public.equipment_fault_audit
  from anon, authenticated, metra_api_runtime, service_role;
revoke execute on function public.equipment_faults_guard_write() from public, anon, authenticated;
revoke execute on function public.equipment_faults_append_audit() from public, anon, authenticated;
revoke execute on function public.equipment_fault_audit_reject_mutation() from public, anon, authenticated;

comment on table public.equipment_faults is
  'Equipment fault current state; station-scoped; writes require transaction-local METRA actor/station/reason context.';
comment on table public.equipment_fault_audit is
  'Append-only equipment fault lifecycle audit; entries are created atomically by database triggers.';

commit;
