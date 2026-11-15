CREATE OR REPLACE FUNCTION public.get_station_user_directory(p_station_id uuid,p_limit integer DEFAULT 250)
RETURNS SETOF jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog','public'
AS $function$
BEGIN
 IF p_station_id IS NULL OR p_limit IS NULL OR p_limit < 1 OR p_limit > 500 THEN
  RAISE EXCEPTION 'invalid_station_user_directory_query' USING ERRCODE='22023';
 END IF;
 RETURN QUERY
 SELECT jsonb_build_object(
  'user_id',p.user_id,'first_name',p.first_name,'father_name',p.father_name,'last_name',p.last_name,
  'phone',p.phone,'account_state',state.account_state,'state_reason',state.state_reason,
  'assignment_id',a.id,'assignment_role_code',a.assignment_role_code,'assignment_status',a.approval_status,
  'valid_from',a.valid_from,'valid_to',a.valid_to,'station_id',a.station_id,
  'role_name_ar',role.name_ar,'role_name_en',role.name_en
 )
 FROM public.station_assignments a
 JOIN public.metra_user_profiles p ON p.user_id=a.user_id
 LEFT JOIN public.metra_account_states state ON state.user_id=a.user_id
 LEFT JOIN public.metra_role_catalogue role ON role.role_code=a.assignment_role_code
 WHERE a.station_id=p_station_id
 ORDER BY CASE a.approval_status WHEN 'approved' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END,
          p.last_name,p.first_name,a.valid_from DESC
 LIMIT p_limit;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_station_user_directory(uuid,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_station_user_directory(uuid,integer) FROM anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_user_directory(uuid,integer) TO service_role;