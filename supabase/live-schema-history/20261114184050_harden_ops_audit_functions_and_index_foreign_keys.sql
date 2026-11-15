
create index if not exists metra_equipment_fault_audit_actor_user_idx
  on public.metra_equipment_fault_audit_events (actor_user_id);
create index if not exists metra_equipment_fault_audit_fault_idx
  on public.metra_equipment_fault_audit_events (fault_id);
create index if not exists metra_equipment_fault_audit_station_idx
  on public.metra_equipment_fault_audit_events (station_id);
create index if not exists metra_equipment_faults_assigned_to_idx
  on public.metra_equipment_faults (assigned_to);
create index if not exists metra_equipment_faults_reporter_user_idx
  on public.metra_equipment_faults (reporter_user_id);
create index if not exists metra_support_incident_audit_actor_user_idx
  on public.metra_support_incident_audit_events (actor_user_id);
create index if not exists metra_support_incident_audit_incident_idx
  on public.metra_support_incident_audit_events (incident_id);
create index if not exists metra_support_incident_audit_station_idx
  on public.metra_support_incident_audit_events (station_id);
create index if not exists metra_support_incidents_assigned_to_idx
  on public.metra_support_incidents (assigned_to);
create index if not exists metra_support_incidents_reporter_user_idx
  on public.metra_support_incidents (reporter_user_id);

alter function public.reject_metra_equipment_fault_audit_mutation()
  set search_path = '';
alter function public.reject_metra_support_incident_audit_mutation()
  set search_path = '';
