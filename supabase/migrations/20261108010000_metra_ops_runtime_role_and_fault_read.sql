-- NEW METRA project only. Do not apply without explicit approval.
-- Do not touch the legacy INSERT database.
-- Creates constrained NOLOGIN group roles for API operations and tightens grants.

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

-- Grant only the identity sequences used by operational audit inserts.
grant usage, select on sequence
  public.metra_equipment_fault_audit_events_id_seq,
  public.metra_support_incident_audit_events_id_seq
  to metra_ops_faults;
