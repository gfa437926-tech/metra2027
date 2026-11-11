-- METRA 2027: least-privilege, station-scoped imported observation archive reads.
-- This migration is a reviewed proposal. Do not apply until the owner approves
-- the permission issuance policy and the backend integration tests pass.
begin;

create or replace function private.metra_actor_can_read_station_archive(
    p_actor_user_id uuid,
    p_station_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
    select
        p_actor_user_id is not null
        and p_station_id is not null
        and exists (
            select 1
            from public.metra_account_states s
            join public.permission_grants g
              on g.user_id = s.user_id
            join public.station_assignments a
              on a.user_id = s.user_id
             and a.authority_id = g.authority_id
            join public.station_catalogue st
              on st.id = a.station_id
             and st.owner_authority_id = a.authority_id
            where s.user_id = p_actor_user_id
              and s.account_state = 'active'
              and g.permission_code = 'observation.archive.read'
              and g.approval_status = 'approved'
              and g.valid_from <= statement_timestamp()
              and (g.valid_to is null or g.valid_to > statement_timestamp())
              and (g.revoked_at is null or g.revoked_at > statement_timestamp())
              and a.station_id = p_station_id
              and a.approval_status = 'approved'
              and a.valid_from <= statement_timestamp()
              and (a.valid_to is null or a.valid_to > statement_timestamp())
              and st.approval_status = 'approved'
              and st.operational_status = 'active'
        );
$function$;

revoke all on function private.metra_actor_can_read_station_archive(uuid, uuid)
    from public, anon, authenticated;

create or replace function public.metra_station_observation_archive_page(
    p_actor_user_id uuid,
    p_station_id uuid,
    p_observation_type text default null,
    p_from_utc timestamptz default null,
    p_to_utc timestamptz default null,
    p_limit integer default 50,
    p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
    v_items jsonb;
    v_returned integer;
begin
    if coalesce(auth.role(), '') <> 'service_role' then
        raise insufficient_privilege using message = 'service_role_required';
    end if;

    if p_actor_user_id is null or p_station_id is null
       or p_limit is null or p_limit < 1 or p_limit > 100
       or p_offset is null or p_offset < 0 or p_offset > 100000
       or (p_observation_type is not null and p_observation_type not in
           ('daily', 'hourly', 'climate', 'soil', 'agricultural', 'phenomenon', 'fieldclimate'))
       or (p_from_utc is not null and p_to_utc is not null and p_from_utc >= p_to_utc) then
        raise invalid_parameter_value using message = 'invalid_archive_query';
    end if;

    if not private.metra_actor_can_read_station_archive(p_actor_user_id, p_station_id) then
        return jsonb_build_object('authorized', false);
    end if;

    select
        coalesce(jsonb_agg(
            jsonb_build_object(
                'id', q.id,
                'stationId', q.station_id,
                'sourceSystem', q.source_system,
                'sourceTable', q.source_table,
                'sourceRecordId', q.source_record_id,
                'observationType', q.observation_type,
                'observedAtUtc', q.observed_at,
                'payload', q.payload,
                'importedAtUtc', q.imported_at
            ) order by q.observed_at desc nulls last, q.id desc
        ), '[]'::jsonb),
        count(*)::integer
    into v_items, v_returned
    from (
        select r.id, r.station_id, r.source_system, r.source_table,
               r.source_record_id, r.observation_type, r.observed_at,
               r.payload, r.imported_at
        from public.metra_observation_records r
        where r.station_id = p_station_id
          and not r.is_demo
          and (p_observation_type is null or r.observation_type = p_observation_type)
          and (p_from_utc is null or
               (r.observed_at is not null and r.observed_at >= p_from_utc))
          and (p_to_utc is null or
               (r.observed_at is not null and r.observed_at < p_to_utc))
        order by r.observed_at desc nulls last, r.id desc
        limit p_limit offset p_offset
    ) q;

    return jsonb_build_object(
        'authorized', true,
        'items', v_items,
        'page', jsonb_build_object(
            'limit', p_limit,
            'offset', p_offset,
            'returned', v_returned
        )
    );
end;
$function$;

revoke all on function public.metra_station_observation_archive_page(
    uuid, uuid, text, timestamptz, timestamptz, integer, integer
) from public, anon, authenticated;
grant execute on function public.metra_station_observation_archive_page(
    uuid, uuid, text, timestamptz, timestamptz, integer, integer
) to service_role;

create or replace function public.metra_station_observation_archive_detail(
    p_actor_user_id uuid,
    p_station_id uuid,
    p_observation_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
    v_item jsonb;
begin
    if coalesce(auth.role(), '') <> 'service_role' then
        raise insufficient_privilege using message = 'service_role_required';
    end if;

    if p_actor_user_id is null or p_station_id is null or p_observation_id is null then
        raise invalid_parameter_value using message = 'invalid_archive_detail_query';
    end if;

    if not private.metra_actor_can_read_station_archive(p_actor_user_id, p_station_id) then
        return jsonb_build_object('authorized', false);
    end if;

    select jsonb_build_object(
        'id', r.id,
        'stationId', r.station_id,
        'sourceSystem', r.source_system,
        'sourceTable', r.source_table,
        'sourceRecordId', r.source_record_id,
        'observationType', r.observation_type,
        'observedAtUtc', r.observed_at,
        'payload', r.payload,
        'importedAtUtc', r.imported_at
    )
    into v_item
    from public.metra_observation_records r
    where r.id = p_observation_id
      and r.station_id = p_station_id
      and not r.is_demo;

    if v_item is null then
        return jsonb_build_object('authorized', true, 'found', false);
    end if;

    return jsonb_build_object('authorized', true, 'found', true, 'item', v_item);
end;
$function$;

revoke all on function public.metra_station_observation_archive_detail(uuid, uuid, uuid)
    from public, anon, authenticated;
grant execute on function public.metra_station_observation_archive_detail(uuid, uuid, uuid)
    to service_role;

commit;
