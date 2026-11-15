-- Station-scoped IT/telecom support incidents for the NEW METRA project only.
-- Do not apply without explicit approval. Does not touch the legacy INSERT database.

create table if not exists public.metra_support_incidents (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.station_catalogue(id),
  reporter_user_id uuid not null references auth.users(id),
  kind text not null check (kind in ('InformationTechnology','Telecommunications')),
  category text not null check (char_length(trim(category)) between 2 and 80),
  title text not null check (char_length(trim(title)) between 5 and 160),
  description text not null check (char_length(trim(description)) between 10 and 5000),
  affected_asset text check (affected_asset is null or char_length(trim(affected_asset)) between 1 and 160),
  severity text not null check (severity in ('Low','Normal','High','Critical')),
  status text not null check (status in (
    'Submitted','UnderReview','Assigned','InProgress','WaitingForInformation','Resolved','Closed','Rejected'
  )),
  impacts_operations boolean not null default false,
  occurred_at timestamptz not null,
  assigned_to uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists metra_support_incidents_station_status_idx
  on public.metra_support_incidents (station_id, status, occurred_at desc);

create table if not exists public.metra_support_incident_audit_events (
  id bigint generated always as identity primary key,
  incident_id uuid not null references public.metra_support_incidents(id),
  station_id uuid not null references public.station_catalogue(id),
  actor_user_id uuid not null references auth.users(id),
  event_type text not null,
  from_status text,
  to_status text not null,
  note text,
  occurred_at timestamptz not null default now()
);

create or replace function public.reject_metra_support_incident_audit_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'metra_support_incident_audit_immutable' using errcode = '42501';
end;
$$;

drop trigger if exists metra_support_incident_audit_immutable on public.metra_support_incident_audit_events;
create trigger metra_support_incident_audit_immutable
before update or delete on public.metra_support_incident_audit_events
for each row execute function public.reject_metra_support_incident_audit_mutation();

create or replace function public.metra_submit_support_incident(
  p_user_id uuid,
  p_station_id uuid,
  p_kind text,
  p_category text,
  p_title text,
  p_description text,
  p_affected_asset text,
  p_severity text,
  p_occurred_at timestamptz,
  p_impacts_operations boolean default false
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_user_id is null or p_station_id is null then
    raise exception 'user_station_required' using errcode = '22023';
  end if;
  if p_kind is null or p_kind not in ('InformationTechnology','Telecommunications') then
    raise exception 'invalid_support_kind' using errcode = '22023';
  end if;
  if p_severity is null or p_severity not in ('Low','Normal','High','Critical') then
    raise exception 'invalid_support_severity' using errcode = '22023';
  end if;
  if not public.metra_user_has_station_permission(p_user_id, p_station_id, 'support_incident.create') then
    raise exception 'station_support_incident_create_forbidden' using errcode = '42501';
  end if;

  insert into public.metra_support_incidents (
    station_id, reporter_user_id, kind, category, title, description, affected_asset,
    severity, status, impacts_operations, occurred_at
  ) values (
    p_station_id, p_user_id, p_kind, trim(p_category), trim(p_title), trim(p_description),
    nullif(trim(p_affected_asset), ''), p_severity, 'Submitted',
    coalesce(p_impacts_operations, false), p_occurred_at
  ) returning id into v_id;

  insert into public.metra_support_incident_audit_events (
    incident_id, station_id, actor_user_id, event_type, from_status, to_status
  ) values (v_id, p_station_id, p_user_id, 'submitted', null, 'Submitted');

  return jsonb_build_object('id', v_id, 'status', 'Submitted');
end;
$$;

create or replace function public.metra_transition_support_incident(
  p_user_id uuid,
  p_station_id uuid,
  p_incident_id uuid,
  p_to_status text,
  p_note text default null,
  p_assigned_to uuid default null
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_row public.metra_support_incidents%rowtype;
  v_permission text;
begin
  if p_user_id is null or p_station_id is null or p_incident_id is null then
    raise exception 'user_station_incident_required' using errcode = '22023';
  end if;

  select * into v_row from public.metra_support_incidents
  where id = p_incident_id and station_id = p_station_id for update;
  if not found then
    raise exception 'support_incident_not_found' using errcode = 'P0002';
  end if;

  if p_to_status is null or p_to_status not in (
    'UnderReview','Assigned','InProgress','WaitingForInformation','Resolved','Closed','Rejected'
  ) then
    raise exception 'invalid_support_transition' using errcode = '22023';
  end if;

  v_permission := case
    when p_to_status in ('UnderReview','Rejected') then 'support_incident.review'
    when p_to_status = 'Assigned' then 'support_incident.assign'
    when p_to_status in ('InProgress','WaitingForInformation','Resolved','Closed') then 'support_incident.resolve'
    else null
  end;
  if v_permission is null
     or not public.metra_user_has_station_permission(p_user_id, p_station_id, v_permission) then
    raise exception 'station_support_incident_transition_forbidden' using errcode = '42501';
  end if;

  if not (
    (v_row.status = 'Submitted' and p_to_status in ('UnderReview','Rejected'))
    or (v_row.status = 'UnderReview' and p_to_status in ('Assigned','Rejected'))
    or (v_row.status = 'Assigned' and p_to_status in ('InProgress','UnderReview'))
    or (v_row.status = 'InProgress' and p_to_status in ('WaitingForInformation','Resolved','Assigned'))
    or (v_row.status = 'WaitingForInformation' and p_to_status in ('InProgress','Resolved'))
    or (v_row.status = 'Resolved' and p_to_status in ('Closed','InProgress'))
  ) then
    raise exception 'invalid_support_state_transition' using errcode = '22023';
  end if;

  update public.metra_support_incidents
     set status = p_to_status,
         assigned_to = case when p_to_status = 'Assigned' then coalesce(p_assigned_to, assigned_to) else assigned_to end,
         updated_at = now()
   where id = p_incident_id and station_id = p_station_id;

  insert into public.metra_support_incident_audit_events (
    incident_id, station_id, actor_user_id, event_type, from_status, to_status, note
  ) values (
    p_incident_id, p_station_id, p_user_id, lower(p_to_status), v_row.status, p_to_status, nullif(trim(p_note), '')
  );

  return jsonb_build_object('id', p_incident_id, 'status', p_to_status);
end;
$$;

revoke all on function public.metra_submit_support_incident(uuid,uuid,text,text,text,text,text,text,timestamptz,boolean)
  from public, anon, authenticated;
grant execute on function public.metra_submit_support_incident(uuid,uuid,text,text,text,text,text,text,timestamptz,boolean)
  to service_role;
revoke all on function public.metra_transition_support_incident(uuid,uuid,uuid,text,text,uuid)
  from public, anon, authenticated;
grant execute on function public.metra_transition_support_incident(uuid,uuid,uuid,text,text,uuid)
  to service_role;
revoke all on table public.metra_support_incidents from public, anon, authenticated;
revoke all on table public.metra_support_incident_audit_events from public, anon, authenticated;
grant select, insert, update on table public.metra_support_incidents to service_role;
grant select, insert on table public.metra_support_incident_audit_events to service_role;
