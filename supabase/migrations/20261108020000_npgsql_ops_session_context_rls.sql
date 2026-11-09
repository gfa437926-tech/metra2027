-- NEW METRA only. Session-scoped RLS for limited ops DB role used by Npgsql.
-- Does not touch the legacy INSERT database.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'metra_ops_faults') then
    create role metra_ops_faults nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'metra_api_runtime') then
    create role metra_api_runtime nologin;
  end if;
end $$;

grant usage on schema public to metra_ops_faults, metra_api_runtime;
grant metra_ops_faults to metra_api_runtime;

-- Runtime login role may set role into the constrained ops role for the session/transaction.
-- Actual login users are provisioned out-of-band; grant membership is the control point.

alter table if exists public.metra_equipment_faults enable row level security;
alter table if exists public.metra_equipment_fault_audit_events enable row level security;
alter table if exists public.metra_equipment_faults force row level security;
alter table if exists public.metra_equipment_fault_audit_events force row level security;

alter table if exists public.metra_support_incidents enable row level security;
alter table if exists public.metra_support_incident_audit_events enable row level security;
alter table if exists public.metra_support_incidents force row level security;
alter table if exists public.metra_support_incident_audit_events force row level security;

revoke all on table public.metra_equipment_faults from public, anon, authenticated;
revoke all on table public.metra_equipment_fault_audit_events from public, anon, authenticated;
revoke all on table public.metra_support_incidents from public, anon, authenticated;
revoke all on table public.metra_support_incident_audit_events from public, anon, authenticated;

grant select, insert on table public.metra_equipment_faults to metra_ops_faults;
revoke update on table public.metra_equipment_faults from metra_ops_faults;
grant update (status, assigned_to, progress_percent, progress_note, updated_at)
  on table public.metra_equipment_faults to metra_ops_faults;
grant select, insert on table public.metra_equipment_fault_audit_events to metra_ops_faults;

grant select, insert on table public.metra_support_incidents to metra_ops_faults;
revoke update on table public.metra_support_incidents from metra_ops_faults;
grant update (status, assigned_to, updated_at)
  on table public.metra_support_incidents to metra_ops_faults;
grant select, insert on table public.metra_support_incident_audit_events to metra_ops_faults;

-- Only grant the identity sequences required by the two audit tables.
do $
declare
  v_sequence text;
begin
  for v_sequence in
    select pg_get_serial_sequence('public.metra_equipment_fault_audit_events', 'id')
    union all
    select pg_get_serial_sequence('public.metra_support_incident_audit_events', 'id')
  loop
    if v_sequence is not null then
      execute format('grant usage, select on sequence %s to metra_ops_faults', v_sequence::regclass);
    end if;
  end loop;
end $;

-- Drop previous ops policies if re-applied
drop policy if exists metra_ops_faults_station_isolation on public.metra_equipment_faults;
drop policy if exists metra_ops_fault_audit_station_isolation on public.metra_equipment_fault_audit_events;
drop policy if exists metra_ops_support_station_isolation on public.metra_support_incidents;
drop policy if exists metra_ops_support_audit_station_isolation on public.metra_support_incident_audit_events;

-- Station isolation from transaction-local setting set by the API before any DML.
create policy metra_ops_faults_station_isolation
  on public.metra_equipment_faults
  for all
  to metra_ops_faults
  using (
    station_id = nullif(current_setting('app.station_id', true), '')::uuid
  )
  with check (
    station_id = nullif(current_setting('app.station_id', true), '')::uuid
  );

create policy metra_ops_fault_audit_station_isolation
  on public.metra_equipment_fault_audit_events
  for all
  to metra_ops_faults
  using (
    station_id = nullif(current_setting('app.station_id', true), '')::uuid
  )
  with check (
    station_id = nullif(current_setting('app.station_id', true), '')::uuid
  );

create policy metra_ops_support_station_isolation
  on public.metra_support_incidents
  for all
  to metra_ops_faults
  using (
    station_id = nullif(current_setting('app.station_id', true), '')::uuid
  )
  with check (
    station_id = nullif(current_setting('app.station_id', true), '')::uuid
  );

create policy metra_ops_support_audit_station_isolation
  on public.metra_support_incident_audit_events
  for all
  to metra_ops_faults
  using (
    station_id = nullif(current_setting('app.station_id', true), '')::uuid
  )
  with check (
    station_id = nullif(current_setting('app.station_id', true), '')::uuid
  );
