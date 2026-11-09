-- NEW METRA project only. Do not apply without explicit approval.
-- Do not touch the legacy INSERT database.
-- Creates a constrained DB login role for API fault operations and tightens grants.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'metra_api_runtime') then
    create role metra_api_runtime nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'metra_ops_faults') then
    create role metra_ops_faults nologin;
  end if;
end $$;

grant usage on schema public to metra_api_runtime, metra_ops_faults;

-- Fault tables: no direct client access; runtime roles only via security definer RPCs or controlled grants.
revoke all on table public.metra_equipment_faults from public, anon, authenticated;
revoke all on table public.metra_equipment_fault_audit_events from public, anon, authenticated;

grant select, insert on table public.metra_equipment_faults to metra_ops_faults;
revoke update on table public.metra_equipment_faults from metra_ops_faults;
grant update (status, assigned_to, progress_percent, progress_note, updated_at)
  on table public.metra_equipment_faults to metra_ops_faults;
grant select, insert on table public.metra_equipment_fault_audit_events to metra_ops_faults;
grant metra_ops_faults to metra_api_runtime;

-- Ensure RLS remains enabled (deny-by-default without policies for clients).
alter table if exists public.metra_equipment_faults enable row level security;
alter table if exists public.metra_equipment_fault_audit_events enable row level security;

-- Only the two operational audit identity sequences are in scope. Do not grant
-- access to unrelated sequences in the public schema.
do $
declare
  v_sequence text;
begin
  for v_sequence in
    select pg_get_serial_sequence('public.metra_equipment_fault_audit_events', 'id')
    where to_regclass('public.metra_equipment_fault_audit_events') is not null
    union all
    select pg_get_serial_sequence('public.metra_support_incident_audit_events', 'id')
    where to_regclass('public.metra_support_incident_audit_events') is not null
  loop
    if v_sequence is not null then
      execute format('grant usage, select on sequence %s to metra_ops_faults', v_sequence::regclass);
    end if;
  end loop;
end $;
