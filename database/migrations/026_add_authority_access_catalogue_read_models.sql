CREATE OR REPLACE FUNCTION public.get_authority_membership_roles(p_authority_id uuid)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
 IF p_authority_id IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.meteorological_authorities a
  JOIN public.countries c ON c.id=a.country_id
  WHERE a.id=p_authority_id AND a.is_active AND c.is_active
 ) THEN RAISE EXCEPTION 'authority_unavailable' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT jsonb_build_object(
  'role_code',r.role_code,'name_ar',r.name_ar,'name_en',r.name_en,
  'description_ar',r.description_ar,'description_en',r.description_en,
  'is_requestable',r.is_requestable,'display_order',r.display_order)
 FROM public.metra_role_catalogue r WHERE r.is_active ORDER BY r.display_order,r.role_code;
END $function$
;

CREATE OR REPLACE FUNCTION public.get_authority_permission_options(p_authority_id uuid, p_actor_user_id uuid)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
 IF p_authority_id IS NULL OR p_actor_user_id IS NULL THEN
  RAISE EXCEPTION 'authority_permission_options_invalid' USING ERRCODE='22023';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.metra_account_states a
  WHERE a.user_id=p_actor_user_id AND a.account_state='active') THEN
  RAISE EXCEPTION 'account_not_active' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.meteorological_authorities a
  JOIN public.countries c ON c.id=a.country_id
  WHERE a.id=p_authority_id AND a.is_active AND c.is_active) THEN
  RAISE EXCEPTION 'authority_unavailable' USING ERRCODE='42501';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.authority_memberships m
  JOIN public.metra_role_catalogue r ON r.role_code=m.membership_role_code AND r.is_active
  WHERE m.user_id=p_actor_user_id AND m.authority_id=p_authority_id
   AND m.approval_status='approved' AND m.valid_from<=statement_timestamp()
   AND(m.valid_to IS NULL OR m.valid_to>statement_timestamp())) THEN
  RAISE EXCEPTION 'authority_membership_required' USING ERRCODE='42501';
 END IF;
 RETURN QUERY SELECT DISTINCT jsonb_build_object('permission_code',rp.permission_code)
 FROM public.authority_memberships m
 JOIN public.metra_role_catalogue r ON r.role_code=m.membership_role_code AND r.is_active
 JOIN public.metra_role_permissions rp ON rp.role_code=r.role_code
 WHERE m.user_id=p_actor_user_id AND m.authority_id=p_authority_id
  AND m.approval_status='approved' AND m.valid_from<=statement_timestamp()
  AND(m.valid_to IS NULL OR m.valid_to>statement_timestamp())
 ORDER BY 1;
END $function$
;
REVOKE ALL ON FUNCTION public.get_authority_membership_roles(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.get_authority_permission_options(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_authority_membership_roles(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_authority_permission_options(uuid,uuid) TO service_role;
