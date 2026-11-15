grant select on public.registration_audit_events to metra_api_runtime;
create policy registration_audit_events_api_runtime_read
  on public.registration_audit_events for select to metra_api_runtime using (true);