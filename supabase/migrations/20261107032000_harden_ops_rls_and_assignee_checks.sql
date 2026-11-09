-- Harden equipment faults and support incidents for the NEW METRA project only.
-- Do not apply without explicit approval. Does not touch the legacy INSERT database.
-- Goals:
-- 1) Enable RLS with no client policies (deny-by-default for anon/authenticated).
-- 2) Require assignees to hold the relevant station permission before assignment.
-- 3) Keep service_role + security-definer RPCs as the only write path.

-- ---------- RLS: equipment faults ----------
alter table if exists public.metra_equipment_faults enable row level security;
alter table if exists public.metra_equipment_fault_audit_events enable row level security;

revoke all on table public.metra_equipment_faults from public, anon, authenticated, service_role;
revoke all on table public.metra_equipment_fault_audit_events from public, anon, authenticated, service_role;
-- The REST adapter needs direct SELECT only. All writes go through the
-- permission-checking SECURITY DEFINER RPCs below; do not let service_role
-- bypass those workflow checks with direct table mutations.
grant select on table public.metra_equipment_faults to service_role;

-- Explicitly drop any accidental client policies if present.
do $$
declare
  r record;
begin
  for r in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('metra_equipment_faults', 'metra_equipment_fault_audit_events')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname,
      case
        when exists (
          select 1 from pg_policies p
          where p.schemaname = 'public' and p.tablename = 'metra_equipment_faults' and p.policyname = r.policyname
        ) then 'metra_equipment_faults'
        else 'metra_equipment_fault_audit_events'
      end);
  end loop;
end $$;

-- ---------- RLS: support incidents ----------
alter table if exists public.metra_support_incidents enable row level security;
alter table if exists public.metra_support_incident_audit_events enable row level security;

revoke all on table public.metra_support_incidents from public, anon, authenticated, service_role;
revoke all on table public.metra_support_incident_audit_events from public, anon, authenticated, service_role;
-- The REST adapter needs direct SELECT only. All writes go through the
-- permission-checking SECURITY DEFINER RPCs below.
grant select on table public.metra_support_incidents to service_role;

-- ---------- Assignee authorization for equipment faults ----------
create or replace function public.metra_transition_equipment_fault(
  p_user_id uuid,
  p_station_id uuid,
  p_fault_id uuid,
  p_to_status text,
  p_note text default null,
  p_progress_percent int default null,
  p_assigned_to uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_row public.metra_equipment_faults%rowtype;
  v_from text;
  v_permission text;
begin
  if p_user_id is null or p_station_id is null or p_fault_id is null then
    raise exception 'user_station_fault_required' using errcode = '22023';
  end if;
  if p_to_status is null or p_to_status not in (
    'UnderReview','Assigned','InProgress','Resolved','Closed','Rejected','Submitted'
  ) then
    raise exception 'invalid_fault_status' using errcode = '22023';
  end if;

  v_permission := case p_to_status
    when 'UnderReview' then 'equipment_fault.review'
    when 'Assigned' then 'equipment_fault.assign'
    when 'InProgress' then 'equipment_fault.update'
    when 'Resolved' then 'equipment_fault.resolve'
    when 'Closed' then 'equipment_fault.resolve'
    when 'Rejected' then 'equipment_fault.review'
    else 'equipment_fault.review'
  end;

  if not public.metra_user_has_station_permission(p_user_id, p_station_id, v_permission) then
    raise exception 'station_equipment_fault_transition_forbidden' using errcode = '42501';
  end if;

  select * into v_row
  from public.metra_equipment_faults
  where id = p_fault_id
  for update;

  if not found then
    raise exception 'equipment_fault_not_found' using errcode = 'P0002';
  end if;
  if v_row.station_id <> p_station_id then
    raise exception 'equipment_fault_station_mismatch' using errcode = '42501';
  end if;

  v_from := v_row.status;

  if not (
    (v_from = 'Submitted' and p_to_status in ('UnderReview','Rejected'))
    or (v_from = 'UnderReview' and p_to_status in ('Assigned','Rejected'))
    or (v_from = 'Assigned' and p_to_status in ('InProgress','UnderReview'))
    or (v_from = 'InProgress' and p_to_status in ('Resolved','Assigned'))
    or (v_from = 'Resolved' and p_to_status in ('Closed','InProgress'))
  ) then
    raise exception 'equipment_fault_illegal_transition' using errcode = '22023';
  end if;

  if p_to_status = 'Assigned' then
    if p_assigned_to is null and v_row.assigned_to is null then
      raise exception 'assignee_required' using errcode = '22023';
    end if;
    if p_assigned_to is not null then
      if not public.metra_user_has_station_permission(p_assigned_to, p_station_id, 'equipment_fault.update') then
        raise exception 'assignee_not_authorized_for_station' using errcode = '42501';
      end if;
    end if;
  end if;

  if p_to_status in ('Rejected','Closed') and (p_note is null or char_length(trim(p_note)) < 1) then
    raise exception 'transition_note_required' using errcode = '22023';
  end if;

  if p_to_status = 'Resolved' and coalesce(p_progress_percent, v_row.progress_percent) <> 100 then
    raise exception 'resolve_requires_full_progress' using errcode = '22023';
  end if;

  if p_progress_percent is not null and (p_progress_percent < 0 or p_progress_percent > 100) then
    raise exception 'invalid_progress_percent' using errcode = '22023';
  end if;

  update public.metra_equipment_faults
  set status = p_to_status,
      assigned_to = case
        when p_to_status = 'Assigned' then coalesce(p_assigned_to, assigned_to)
        else assigned_to
      end,
      progress_percent = coalesce(p_progress_percent, progress_percent),
      progress_note = case when p_note is null then progress_note else nullif(trim(p_note), '') end,
      updated_at = now()
  where id = p_fault_id;

  insert into public.metra_equipment_fault_audit_events (
    fault_id, station_id, actor_user_id, event_type, from_status, to_status, note
  ) values (
    p_fault_id, p_station_id, p_user_id, 'status_transition', v_from, p_to_status, nullif(trim(coalesce(p_note, '')), '')
  );

  select * into v_row from public.metra_equipment_faults where id = p_fault_id;
  return to_jsonb(v_row);
end;
$$;

-- ---------- Assignee authorization for support incidents ----------
create or replace function public.metra_transition_support_incident(
  p_user_id uuid,
  p_station_id uuid,
  p_incident_id uuid,
  p_to_status text,
  p_note text default null,
  p_assigned_to uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_row public.metra_support_incidents%rowtype;
  v_from text;
  v_permission text;
begin
  if p_user_id is null or p_station_id is null or p_incident_id is null then
    raise exception 'user_station_incident_required' using errcode = '22023';
  end if;

  v_permission := case p_to_status
    when 'UnderReview' then 'support_incident.review'
    when 'Assigned' then 'support_incident.assign'
    when 'InProgress' then 'support_incident.update'
    when 'WaitingForInformation' then 'support_incident.update'
    when 'Resolved' then 'support_incident.resolve'
    when 'Closed' then 'support_incident.resolve'
    when 'Rejected' then 'support_incident.review'
    else 'support_incident.review'
  end;

  if not public.metra_user_has_station_permission(p_user_id, p_station_id, v_permission) then
    raise exception 'station_support_incident_transition_forbidden' using errcode = '42501';
  end if;

  select * into v_row
  from public.metra_support_incidents
  where id = p_incident_id
  for update;

  if not found then
    raise exception 'support_incident_not_found' using errcode = 'P0002';
  end if;
  if v_row.station_id <> p_station_id then
    raise exception 'support_incident_station_mismatch' using errcode = '42501';
  end if;

  v_from := v_row.status;

  if not (
    (v_from = 'Submitted' and p_to_status in ('UnderReview','Rejected'))
    or (v_from = 'UnderReview' and p_to_status in ('Assigned','Rejected'))
    or (v_from = 'Assigned' and p_to_status in ('InProgress','UnderReview'))
    or (v_from = 'InProgress' and p_to_status in ('WaitingForInformation','Resolved','Assigned'))
    or (v_from = 'WaitingForInformation' and p_to_status in ('InProgress','Resolved'))
    or (v_from = 'Resolved' and p_to_status in ('Closed','InProgress'))
  ) then
    raise exception 'support_incident_illegal_transition' using errcode = '22023';
  end if;

  if p_to_status = 'Assigned' then
    if p_assigned_to is null and v_row.assigned_to is null then
      raise exception 'assignee_required' using errcode = '22023';
    end if;
    if p_assigned_to is not null then
      if not public.metra_user_has_station_permission(p_assigned_to, p_station_id, 'support_incident.update') then
        raise exception 'assignee_not_authorized_for_station' using errcode = '42501';
      end if;
    end if;
  end if;

  if p_to_status in ('Rejected','Closed') and (p_note is null or char_length(trim(p_note)) < 1) then
    raise exception 'transition_note_required' using errcode = '22023';
  end if;

  update public.metra_support_incidents
  set status = p_to_status,
      assigned_to = case when p_to_status = 'Assigned' then coalesce(p_assigned_to, assigned_to) else assigned_to end,
      updated_at = now()
  where id = p_incident_id;

  insert into public.metra_support_incident_audit_events (
    incident_id, station_id, actor_user_id, event_type, from_status, to_status, note
  ) values (
    p_incident_id, p_station_id, p_user_id, 'status_transition', v_from, p_to_status, nullif(trim(coalesce(p_note, '')), '')
  );

  select * into v_row from public.metra_support_incidents where id = p_incident_id;
  return to_jsonb(v_row);
end;
$$;

revoke all on function public.metra_transition_equipment_fault(uuid, uuid, uuid, text, text, int, uuid) from public, anon, authenticated;
revoke all on function public.metra_transition_support_incident(uuid, uuid, uuid, text, text, uuid) from public, anon, authenticated;
grant execute on function public.metra_transition_equipment_fault(uuid, uuid, uuid, text, text, int, uuid) to service_role;
grant execute on function public.metra_transition_support_incident(uuid, uuid, uuid, text, text, uuid) to service_role;
