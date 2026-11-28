CREATE OR REPLACE FUNCTION public.get_authority_access_queue(p_authority_id uuid,p_target_kind text,p_actor_user_id uuid,p_limit integer DEFAULT 50)
RETURNS SETOF jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $$
BEGIN
 IF p_authority_id IS NULL OR p_actor_user_id IS NULL OR p_target_kind NOT IN('membership','permission_grant','membership_active','permission_grant_active') OR p_target_kind IS NULL OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'authority_access_queue_invalid' USING ERRCODE='22023'; END IF;
 IF p_target_kind IN('membership_active','permission_grant_active') THEN
  IF NOT public.metra_user_has_authority_permission(p_actor_user_id,p_authority_id,'authority.access.revoke') THEN RAISE EXCEPTION 'authority_access_directory_forbidden' USING ERRCODE='42501'; END IF;
 ELSE
  IF NOT public.metra_user_has_authority_permission(p_actor_user_id,p_authority_id,'authority.access.review') THEN RAISE EXCEPTION 'authority_access_queue_forbidden' USING ERRCODE='42501'; END IF;
 END IF;
 IF p_target_kind IN('membership','membership_active') THEN
  RETURN QUERY SELECT jsonb_build_object('id',m.id,'user_id',m.user_id,'authority_id',m.authority_id,'role_code',m.membership_role_code,'status',m.approval_status,'reason',m.reason,'requested_by',m.requested_by,'created_at',m.created_at,'valid_from',m.valid_from,'valid_to',m.valid_to)
   FROM public.authority_memberships m WHERE m.authority_id=p_authority_id AND m.approval_status=CASE WHEN p_target_kind='membership' THEN 'pending' ELSE 'approved' END
    AND (p_target_kind='membership' OR (m.valid_from<=statement_timestamp() AND(m.valid_to IS NULL OR m.valid_to>statement_timestamp())))
   ORDER BY m.created_at,m.id LIMIT p_limit;
 ELSE
  RETURN QUERY SELECT jsonb_build_object('id',g.id,'user_id',g.user_id,'authority_id',g.authority_id,'permission_code',g.permission_code,'status',g.approval_status,'reason',g.reason,'requested_by',g.requested_by,'created_at',g.created_at,'valid_from',g.valid_from,'valid_to',g.valid_to)
   FROM public.permission_grants g WHERE g.authority_id=p_authority_id AND g.approval_status=CASE WHEN p_target_kind='permission_grant' THEN 'pending' ELSE 'approved' END
    AND (p_target_kind='permission_grant' OR (g.revoked_at IS NULL AND g.valid_from<=statement_timestamp() AND(g.valid_to IS NULL OR g.valid_to>statement_timestamp())))
   ORDER BY g.created_at,g.id LIMIT p_limit;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.get_authority_access_queue(uuid,text,uuid,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_authority_access_queue(uuid,text,uuid,integer) TO service_role;
