-- Station-scoped equipment fault reports for the NEW METRA project only.
-- Do not apply without explicit approval. Does not touch the legacy INSERT database.

create table if not exists public.metra_equipment_faults (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.station_catalogue(id),
  reporter_user_id uuid not null references auth.users(id),
  equipment_category text not null check (char_length(trim(equipment_category)) between 2 and 80),
  equipment_name text not null check (char_length(trim(equipment_name)) between 2 and 120),
  description text not null check (char_length(trim(description)) between 10 and 5000),
  severity text not null check (severity in ('Low','Medium','High','Critical')),
  status text not null check (status in (
    'Submitted','UnderReview','Assigned','InProgress','Resolved','Closed','Rejected'
  )),
  is_operationally_blocking boolean not null default false,
  occurred_at timestamptz not null,
  assigned_to uuid references auth.users(id),
  progress_percent int not null default 0 check (progress_percent between 0 and 100),
  progress_note text check (progress_note is null or char_length(trim(progress_note)) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists metra_equipment_faults_station_status_idx
  on public.metra_equipment_faults (station_id, status, occurred_at desc);

create table if not exists public.metra_equipment_fault_audit_events (
  id bigint generated always as identity primary key,
  fault_id uuid not null references public.metra_equipment_faults(id),
  station_id uuid not null references public.station_catalogue(id),
  actor_user_id uuid not null references auth.users(id),
  event_type text not null,
  from_status text,
  to_status text not null,
  note text,
  occurred_at timestamptz not null default now()
);

create or replace function public.reject_metra_equipment_fault_audit_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'metra_equipment_fault_audit_immutable' using errcode = '42501';
end;
$$;

drop trigger if exists metra_equipment_fault_audit_immutable on public.metra_equipment_fault_audit_events;
create trigger metra_equipment_fault_audit_immutable
before update or delete on public.metra_equipment_fault_audit_events
for each row execute function public.reject_metra_equipment_fault_audit_mutation();

create or replace function public.metra_submit_equipment_fault(
  p_user_id uuid,
  p_station_id uuid,
  p_equipment_category text,
  p_equipment_name text,
  p_description text,
  p_severity text,
  p_occurred_at timestamptz,
  p_is_operationally_blocking boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_id uuid;
begin
  if p_user_id is null or p_station_id is null then
    raise exception 'user_station_required' using errcode = '22023';
  end if;
  if p_severity is null or p_severity not in ('Low','Medium','High','Critical') then
    raise exception 'invalid_fault_severity' using errcode = '22023';
  end if;
  if not public.metra_user_has_station_permission(p_user_id, p_station_id, 'equipment_fault.create') then
    raise exception 'station_equipment_fault_create_forbidden' using errcode = '42501';
  end if;

  insert into public.metra_equipment_faults (
    station_id, reporter_user_id, equipment_category, equipment_name, description,
    severity, status, is_operationally_blocking, occurred_at
  ) values (
    p_station_id, p_user_id, trim(p_equipment_category), trim(p_equipment_name), trim(p_description),
    p_severity, 'Submitted', coalesce(p_is_operationally_blocking, false), p_occurred_at
  ) returning id into v_id;

  insert into public.metra_equipment_fault_audit_events (
    fault_id, station_id, actor_user_id, event_type, from_status, to_status
  ) values (
    v_id, p_station_id, p_user_id, 'submitted', null, 'Submitted'
  );

  return jsonb_build_object('id', v_id, 'status', 'Submitted');
end;
$$;

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
  v_permission text;
  v_progress int;
begin
  if p_user_id is null or p_station_id is null or p_fault_id is null then
    raise exception 'user_station_fault_required' using errcode = '22023';
  end if;

  select * into v_row
  from public.metra_equipment_faults
  where id = p_fault_id and station_id = p_station_id
  for update;

  if not found then
    raise exception 'equipment_fault_not_found' using errcode = 'P0002';
  end if;

  if p_to_status is null or p_to_status not in (
    'UnderReview','Assigned','InProgress','Resolved','Closed','Rejected'
  ) then
    raise exception 'invalid_fault_transition' using errcode = '22023';
  end if;

  -- Permission by target state (least privilege).
  v_permission := case
    when p_to_status in ('UnderReview','Rejected') then 'equipment_fault.review'
    when p_to_status = 'Assigned' then 'equipment_fault.assign'
    when p_to_status in ('InProgress','Resolved','Closed') then 'equipment_fault.resolve'
    else null
  end;

  if v_permission is null
     or not public.metra_user_has_station_permission(p_user_id, p_station_id, v_permission) then
    raise exception 'station_equipment_fault_transition_forbidden' using errcode = '42501';
  end if;

  -- Transition matrix (mirrors EquipmentFaultPolicy).
  if not (
    (v_row.status = 'Submitted' and p_to_status in ('UnderReview','Rejected'))
    or (v_row.status = 'UnderReview' and p_to_status in ('Assigned','Rejected'))
    or (v_row.status = 'Assigned' and p_to_status in ('InProgress','UnderReview'))
    or (v_row.status = 'InProgress' and p_to_status in ('Resolved','Assigned'))
    or (v_row.status = 'Resolved' and p_to_status in ('Closed','InProgress'))
  ) then
    raise exception 'invalid_fault_state_transition' using errcode = '22023';
  end if;

  v_progress := coalesce(p_progress_percent, v_row.progress_percent);
  if v_progress < 0 or v_progress > 100 then
    raise exception 'invalid_progress_percent' using errcode = '22023';
  end if;
  if p_to_status = 'Resolved' and v_progress <> 100 then
    raise exception 'resolved_requires_full_progress' using errcode = '22023';
  end if;

  update public.metra_equipment_faults
     set status = p_to_status,
         progress_percent = v_progress,
         progress_note = case when p_note is null then progress_note else nullif(trim(p_note), '') end,
         assigned_to = case
           when p_to_status = 'Assigned' then coalesce(p_assigned_to, assigned_to)
           else assigned_to
         end,
         updated_at = now()
   where id = p_fault_id and station_id = p_station_id;

  insert into public.metra_equipment_fault_audit_events (
    fault_id, station_id, actor_user_id, event_type, from_status, to_status, note
  ) values (
    p_fault_id, p_station_id, p_user_id, lower(p_to_status), v_row.status, p_to_status, nullif(trim(p_note), '')
  );

  return jsonb_build_object('id', p_fault_id, 'status', p_to_status, 'progress_percent', v_progress);
end;
$$;

revoke all on function public.metra_submit_equipment_fault(uuid, uuid, text, text, text, text, timestamptz, boolean)
  from public, anon, authenticated;
grant execute on function public.metra_submit_equipment_fault(uuid, uuid, text, text, text, text, timestamptz, boolean)
  to service_role;

revoke all on function public.metra_transition_equipment_fault(uuid, uuid, uuid, text, text, int, uuid)
  from public, anon, authenticated;
grant execute on function public.metra_transition_equipment_fault(uuid, uuid, uuid, text, text, int, uuid)
  to service_role;

revoke all on table public.metra_equipment_faults from public, anon, authenticated;
revoke all on table public.metra_equipment_fault_audit_events from public, anon, authenticated;
grant select, insert, update on table public.metra_equipment_faults to service_role;
grant select, insert on table public.metra_equipment_fault_audit_events to service_role;
