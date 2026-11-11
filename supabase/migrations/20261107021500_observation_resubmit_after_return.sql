-- Allow the observation creator to resubmit a returned observation.
-- Apply only to the NEW METRA project. Does not touch the legacy INSERT database.

create or replace function public.metra_resubmit_observation(
  p_user_id uuid,
  p_station_id uuid,
  p_observation_id uuid,
  p_payload jsonb default null
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_row public.metra_observations%rowtype;
begin
  if p_user_id is null or p_station_id is null or p_observation_id is null then
    raise exception 'user_station_observation_required' using errcode = '22023';
  end if;

  if p_payload is not null and (
       jsonb_typeof(p_payload) <> 'object'
       or pg_column_size(p_payload) > 65536
     ) then
    raise exception 'invalid_observation_payload' using errcode = '22023';
  end if;

  select * into v_row
  from public.metra_observations
  where id = p_observation_id
    and station_id = p_station_id
  for update;

  if not found then
    raise exception 'observation_not_found' using errcode = 'P0002';
  end if;

  if v_row.created_by <> p_user_id then
    raise exception 'not_observation_owner' using errcode = '42501';
  end if;

  if v_row.status <> 'returned' then
    raise exception 'observation_not_in_returned_state' using errcode = '22023';
  end if;

  if not public.metra_user_has_station_permission(p_user_id, p_station_id, 'observation.submit') then
    raise exception 'station_observation_submit_forbidden' using errcode = '42501';
  end if;

  update public.metra_observations
     set status = 'submitted',
         payload = coalesce(p_payload, payload),
         submitted_at = now(),
         reviewed_by = null,
         reviewed_at = null,
         review_note = null,
         updated_at = now()
   where id = p_observation_id
     and station_id = p_station_id
     and status = 'returned';

  if not found then
    raise exception 'observation_not_in_returned_state' using errcode = '22023';
  end if;

  insert into public.metra_observation_audit_events (
    observation_id, station_id, actor_user_id, event_type, from_status, to_status
  ) values (
    p_observation_id, p_station_id, p_user_id, 'resubmitted', 'returned', 'submitted'
  );

  return jsonb_build_object(
    'id', p_observation_id,
    'status', 'submitted',
    'replayed', false
  );
end;
$$;

revoke all on function public.metra_resubmit_observation(uuid, uuid, uuid, jsonb)
  from public, anon, authenticated, metra_api_runtime;
grant execute on function public.metra_resubmit_observation(uuid, uuid, uuid, jsonb)
  to service_role;
