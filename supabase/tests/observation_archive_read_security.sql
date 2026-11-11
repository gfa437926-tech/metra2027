-- Static security contract checks for the station-scoped archive RPCs.
-- This test runs after the proposed archive migration has been applied in an
-- isolated Supabase test database; it does not seed or grant any user access.
do $$
declare
  page_signature regprocedure;
  detail_signature regprocedure;
  helper_signature regprocedure;
begin
  page_signature := to_regprocedure(
    'public.metra_station_observation_archive_page(uuid,uuid,text,timestamp with time zone,timestamp with time zone,integer,integer)');
  detail_signature := to_regprocedure(
    'public.metra_station_observation_archive_detail(uuid,uuid,uuid)');
  helper_signature := to_regprocedure(
    'private.metra_actor_can_read_station_archive(uuid,uuid)');

  if page_signature is null or detail_signature is null or helper_signature is null then
    raise exception 'Archive read RPC signatures are missing';
  end if;

  if not has_function_privilege('service_role', page_signature, 'EXECUTE')
     or not has_function_privilege('service_role', detail_signature, 'EXECUTE') then
    raise exception 'service_role must execute archive RPCs';
  end if;

  if has_function_privilege('anon', page_signature, 'EXECUTE')
     or has_function_privilege('authenticated', page_signature, 'EXECUTE')
     or has_function_privilege('anon', detail_signature, 'EXECUTE')
     or has_function_privilege('authenticated', detail_signature, 'EXECUTE')
     or has_function_privilege('public', page_signature, 'EXECUTE')
     or has_function_privilege('public', detail_signature, 'EXECUTE') then
    raise exception 'Archive RPC execution must be denied to public client roles';
  end if;

  if has_function_privilege('anon', helper_signature, 'EXECUTE')
     or has_function_privilege('authenticated', helper_signature, 'EXECUTE')
     or has_function_privilege('public', helper_signature, 'EXECUTE') then
    raise exception 'Private authorization helper must not be client executable';
  end if;

  if exists (
    select 1
    from public.metra_role_permissions
    where permission_code = 'observation.archive.read'
  ) then
    raise exception 'Archive read must not be automatically assigned through role matrix';
  end if;

  raise notice 'PASS: archive RPCs are service_role-only and archive permission is not auto-assigned to roles';
end
$$;
