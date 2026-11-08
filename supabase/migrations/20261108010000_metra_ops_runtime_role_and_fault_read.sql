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

grant select, insert, update on table public.metra_equipment_faults to metra_ops_faults;
grant select, insert on table public.metra_equipment_fault_audit_events to metra_ops_faults;
grant metra_ops_faults to metra_api_runtime;

-- Ensure RLS remains enabled (deny-by-default without policies for clients).
alter table if exists public.metra_equipment_faults enable row level security;
alter table if exists public.metra_equipment_fault_audit_events enable row level security;

-- Optional: dedicated sequence/table privileges for identity generation if needed by Npgsql adapters.
grant usage, select on all sequences in schema public to metra_ops_faults;
