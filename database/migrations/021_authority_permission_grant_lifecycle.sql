CREATE OR REPLACE FUNCTION public.request_authority_permission_grant(p_user_id uuid, p_authority_id uuid, p_permission_code text, p_reason text, p_valid_from timestamp with time zone DEFAULT clock_timestamp(), p_valid_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE v_id uuid; n timestamptz:=clock_timestamp();
BEGIN
 IF p_user_id IS NULL OR p_authority_id IS NULL OR p_permission_code IS NULL
  OR length(btrim(p_permission_code)) NOT BETWEEN 1 AND 128 OR p_reason IS NULL
  OR length(btrim(p_reason)) NOT BETWEEN 5 AND 2000 OR p_reason~'[[:cntrl:]]'
  OR p_valid_from IS NULL OR(p_valid_to IS NOT NULL AND p_valid_to<=p_valid_from)
 THEN RAISE EXCEPTION 'invalid_authority_permission_request' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM public.metra_account_states a WHERE a.user_id=p_user_id AND a.account_state='active' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'permission_subject_not_active' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.meteorological_authorities a JOIN public.countries c ON c.id=a.country_id
  WHERE a.id=p_authority_id AND a.is_active AND c.is_active FOR SHARE OF a,c;
 IF NOT FOUND THEN RAISE EXCEPTION 'authority_unavailable' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.authority_memberships m
  JOIN public.metra_role_catalogue r ON r.role_code=m.membership_role_code AND r.is_active
  JOIN public.metra_role_permissions rp ON rp.role_code=r.role_code AND rp.permission_code=p_permission_code
  WHERE m.user_id=p_user_id AND m.authority_id=p_authority_id AND m.approval_status='approved'
   AND m.valid_from<=n AND(m.valid_to IS NULL OR m.valid_to>n) FOR SHARE OF m,r,rp;
 IF NOT FOUND THEN RAISE EXCEPTION 'permission_not_allowed_for_membership' USING ERRCODE='42501'; END IF;
 INSERT INTO public.permission_grants(user_id,authority_id,permission_code,approval_status,valid_from,valid_to,requested_by,reason)
 VALUES(p_user_id,p_authority_id,btrim(p_permission_code),'pending',p_valid_from,p_valid_to,p_user_id,btrim(p_reason))
 RETURNING id INTO v_id;
 INSERT INTO public.authority_access_audit_events(target_kind,target_id,authority_id,subject_user_id,actor_user_id,action_code,from_status,to_status,reason,occurred_at)
 VALUES('permission_grant',v_id,p_authority_id,p_user_id,p_user_id,'requested',NULL,'pending',btrim(p_reason),n);
 RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.decide_authority_permission_grant(p_grant_id uuid, p_actor_user_id uuid, p_decision text, p_reason text, p_occurred_at timestamp with time zone DEFAULT clock_timestamp())
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE v public.permission_grants%ROWTYPE; n timestamptz:=clock_timestamp();
BEGIN
 IF p_grant_id IS NULL OR p_actor_user_id IS NULL OR p_decision IS NULL OR p_decision NOT IN('approve','reject')
  OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 2000 OR p_reason~'[[:cntrl:]]'
  OR p_occurred_at IS NULL THEN RAISE EXCEPTION 'invalid_authority_permission_decision' USING ERRCODE='22023'; END IF;
 SELECT * INTO v FROM public.permission_grants WHERE id=p_grant_id FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF v.approval_status<>'pending' THEN RETURN 'conflict'; END IF;
 IF p_actor_user_id=v.requested_by OR p_actor_user_id=v.user_id THEN RETURN 'unauthorized'; END IF;
 PERFORM 1 FROM public.metra_account_states a WHERE a.user_id=p_actor_user_id AND a.account_state='active' FOR SHARE;
 IF NOT FOUND THEN RETURN 'unauthorized'; END IF;
 PERFORM 1 FROM public.authority_memberships m
  JOIN public.metra_role_catalogue r ON r.role_code=m.membership_role_code AND r.is_active
  JOIN public.metra_role_permissions rp ON rp.role_code=r.role_code AND rp.permission_code='authority.access.review'
  JOIN public.permission_grants g ON g.user_id=m.user_id AND g.authority_id=m.authority_id
   AND g.permission_code='authority.access.review' AND g.approval_status='approved' AND g.revoked_at IS NULL
   AND g.valid_from<=n AND(g.valid_to IS NULL OR g.valid_to>n)
  WHERE m.user_id=p_actor_user_id AND m.authority_id=v.authority_id AND m.approval_status='approved'
   AND m.valid_from<=n AND(m.valid_to IS NULL OR m.valid_to>n) FOR SHARE OF m,r,rp,g;
 IF NOT FOUND THEN RETURN 'unauthorized'; END IF;
 PERFORM 1 FROM public.authority_memberships m
  JOIN public.metra_role_catalogue r ON r.role_code=m.membership_role_code AND r.is_active
  JOIN public.metra_role_permissions rp ON rp.role_code=r.role_code AND rp.permission_code=v.permission_code
  WHERE m.user_id=v.user_id AND m.authority_id=v.authority_id AND m.approval_status='approved'
   AND m.valid_from<=n AND(m.valid_to IS NULL OR m.valid_to>n) FOR SHARE OF m,r,rp;
 IF NOT FOUND THEN RETURN 'conflict'; END IF;
 UPDATE public.permission_grants SET approval_status=CASE p_decision WHEN 'approve' THEN 'approved' ELSE 'rejected' END,
  approved_by=p_actor_user_id,reviewed_at=p_occurred_at WHERE id=p_grant_id AND approval_status='pending';
 IF NOT FOUND THEN RETURN 'conflict'; END IF;
 INSERT INTO public.authority_access_audit_events(target_kind,target_id,authority_id,subject_user_id,actor_user_id,action_code,from_status,to_status,reason,occurred_at)
 VALUES('permission_grant',p_grant_id,v.authority_id,v.user_id,p_actor_user_id,
  CASE p_decision WHEN 'approve' THEN 'approved' ELSE 'rejected' END,'pending',
  CASE p_decision WHEN 'approve' THEN 'approved' ELSE 'rejected' END,btrim(p_reason),p_occurred_at);
 RETURN 'committed';
END $function$
;

CREATE OR REPLACE FUNCTION public.revoke_authority_permission_grant(p_grant_id uuid, p_actor_user_id uuid, p_reason text, p_occurred_at timestamp with time zone DEFAULT clock_timestamp())
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE v public.permission_grants%ROWTYPE; n timestamptz:=clock_timestamp();
BEGIN
 IF p_grant_id IS NULL OR p_actor_user_id IS NULL OR p_reason IS NULL
  OR length(btrim(p_reason)) NOT BETWEEN 5 AND 2000 OR p_reason~'[[:cntrl:]]' OR p_occurred_at IS NULL
 THEN RAISE EXCEPTION 'invalid_authority_permission_revocation' USING ERRCODE='22023'; END IF;
 SELECT * INTO v FROM public.permission_grants WHERE id=p_grant_id FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF v.approval_status<>'approved' OR v.revoked_at IS NOT NULL THEN RETURN 'conflict'; END IF;
 IF p_actor_user_id=v.user_id THEN RETURN 'unauthorized'; END IF;
 PERFORM 1 FROM public.metra_account_states a WHERE a.user_id=p_actor_user_id AND a.account_state='active' FOR SHARE;
 IF NOT FOUND THEN RETURN 'unauthorized'; END IF;
 PERFORM 1 FROM public.authority_memberships m
  JOIN public.metra_role_catalogue r ON r.role_code=m.membership_role_code AND r.is_active
  JOIN public.metra_role_permissions rp ON rp.role_code=r.role_code AND rp.permission_code='authority.access.revoke'
  JOIN public.permission_grants g ON g.user_id=m.user_id AND g.authority_id=m.authority_id
   AND g.permission_code='authority.access.revoke' AND g.approval_status='approved' AND g.revoked_at IS NULL
   AND g.valid_from<=n AND(g.valid_to IS NULL OR g.valid_to>n)
  WHERE m.user_id=p_actor_user_id AND m.authority_id=v.authority_id AND m.approval_status='approved'
   AND m.valid_from<=n AND(m.valid_to IS NULL OR m.valid_to>n) FOR SHARE OF m,r,rp,g;
 IF NOT FOUND THEN RETURN 'unauthorized'; END IF;
 UPDATE public.permission_grants SET approval_status='revoked',revoked_at=GREATEST(clock_timestamp(),created_at)
  WHERE id=p_grant_id AND approval_status='approved' AND revoked_at IS NULL;
 IF NOT FOUND THEN RETURN 'conflict'; END IF;
 INSERT INTO public.authority_access_audit_events(target_kind,target_id,authority_id,subject_user_id,actor_user_id,action_code,from_status,to_status,reason,metadata,occurred_at)
 VALUES('permission_grant',p_grant_id,v.authority_id,v.user_id,p_actor_user_id,'revoked','approved','revoked',
  btrim(p_reason),jsonb_build_object('permission_code',v.permission_code),p_occurred_at);
 RETURN 'committed';
END $function$
;

CREATE OR REPLACE FUNCTION public.get_authority_access_queue(p_authority_id uuid, p_target_kind text, p_actor_user_id uuid, p_limit integer DEFAULT 50)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
 IF p_authority_id IS NULL OR p_actor_user_id IS NULL OR p_target_kind NOT IN('membership','permission_grant')
  OR p_target_kind IS NULL OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
  OR NOT public.metra_user_has_authority_permission(p_actor_user_id,p_authority_id,'authority.access.review')
 THEN RAISE EXCEPTION 'authority_access_queue_forbidden_or_invalid' USING ERRCODE='42501'; END IF;
 IF p_target_kind='membership' THEN
  RETURN QUERY SELECT jsonb_build_object('id',m.id,'user_id',m.user_id,'authority_id',m.authority_id,
   'role_code',m.membership_role_code,'status',m.approval_status,'reason',m.reason,
   'requested_by',m.requested_by,'created_at',m.created_at,'valid_from',m.valid_from,'valid_to',m.valid_to)
   FROM public.authority_memberships m WHERE m.authority_id=p_authority_id AND m.approval_status='pending'
   ORDER BY m.created_at,m.id LIMIT p_limit;
 ELSE
  RETURN QUERY SELECT jsonb_build_object('id',g.id,'user_id',g.user_id,'authority_id',g.authority_id,
   'permission_code',g.permission_code,'status',g.approval_status,'reason',g.reason,
   'requested_by',g.requested_by,'created_at',g.created_at,'valid_from',g.valid_from,'valid_to',g.valid_to)
   FROM public.permission_grants g WHERE g.authority_id=p_authority_id AND g.approval_status='pending'
   ORDER BY g.created_at,g.id LIMIT p_limit;
 END IF;
END $function$
;

CREATE OR REPLACE FUNCTION public.get_authority_access_audit(p_authority_id uuid, p_actor_user_id uuid, p_limit integer DEFAULT 100)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
 IF p_authority_id IS NULL OR p_actor_user_id IS NULL OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 200
  OR NOT public.metra_user_has_authority_permission(p_actor_user_id,p_authority_id,'authority.access.review')
 THEN RAISE EXCEPTION 'authority_access_audit_forbidden_or_invalid' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT to_jsonb(e) FROM public.authority_access_audit_events e
  WHERE e.authority_id=p_authority_id ORDER BY e.occurred_at DESC,e.id DESC LIMIT p_limit;
END $function$
;

CREATE OR REPLACE FUNCTION public.decide_station_catalogue_review(p_station_id uuid, p_expected_status text, p_actor_user_id uuid, p_decision text, p_reason text, p_occurred_at timestamp with time zone)
 RETURNS TABLE(result_status text, resulting_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE v_authority_id uuid; n timestamptz:=clock_timestamp();
BEGIN
 IF p_station_id IS NULL OR p_actor_user_id IS NULL OR p_expected_status IS DISTINCT FROM 'pending'
  OR p_decision IS NULL OR p_decision NOT IN('approved','rejected','changes_requested')
  OR p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 5 AND 2000 OR p_reason<>trim(p_reason)
  OR p_reason~'[[:cntrl:]]' OR p_occurred_at IS NULL
 THEN RAISE EXCEPTION 'invalid_station_review_request' USING ERRCODE='22023'; END IF;
 SELECT s.owner_authority_id INTO v_authority_id FROM public.station_catalogue s
  JOIN public.meteorological_authorities a ON a.id=s.owner_authority_id AND a.country_id=s.country_id
  JOIN public.countries c ON c.id=s.country_id
  WHERE s.id=p_station_id AND s.is_demo=false AND a.is_active AND c.is_active
  FOR UPDATE OF s FOR SHARE OF a,c;
 IF v_authority_id IS NULL THEN RAISE EXCEPTION 'station_authority_not_available' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.metra_account_states ac WHERE ac.user_id=p_actor_user_id AND ac.account_state='active' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'reviewer_account_not_active' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.authority_memberships m
  JOIN public.metra_role_catalogue r ON r.role_code=m.membership_role_code AND r.is_active
  JOIN public.metra_role_permissions rp ON rp.role_code=r.role_code AND rp.permission_code='stations.catalogue.review'
  WHERE m.user_id=p_actor_user_id AND m.authority_id=v_authority_id AND m.approval_status='approved'
   AND m.valid_from<=n AND(m.valid_to IS NULL OR m.valid_to>n) FOR SHARE OF m,r,rp;
 IF NOT FOUND THEN RAISE EXCEPTION 'station_review_authority_membership_denied' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.permission_grants g WHERE g.user_id=p_actor_user_id AND g.authority_id=v_authority_id
  AND g.permission_code='stations.catalogue.review' AND g.approval_status='approved' AND g.revoked_at IS NULL
  AND g.valid_from<=n AND(g.valid_to IS NULL OR g.valid_to>n) FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'station_review_permission_denied' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT d.result_status,d.resulting_status FROM private.decide_station_catalogue_review(
  p_station_id,p_expected_status,p_actor_user_id,p_decision,p_reason,p_occurred_at)d;
END $function$
;
REVOKE ALL ON FUNCTION public.request_authority_permission_grant(uuid,uuid,text,text,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.request_authority_permission_grant(uuid,uuid,text,text,timestamptz,timestamptz) TO service_role;
REVOKE ALL ON FUNCTION public.decide_authority_permission_grant(uuid,uuid,text,text,timestamptz) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.decide_authority_permission_grant(uuid,uuid,text,text,timestamptz) TO service_role;
REVOKE ALL ON FUNCTION public.revoke_authority_permission_grant(uuid,uuid,text,timestamptz) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.revoke_authority_permission_grant(uuid,uuid,text,timestamptz) TO service_role;
REVOKE ALL ON FUNCTION public.get_authority_access_queue(uuid,text,uuid,integer) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.get_authority_access_queue(uuid,text,uuid,integer) TO service_role;
REVOKE ALL ON FUNCTION public.get_authority_access_audit(uuid,uuid,integer) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.get_authority_access_audit(uuid,uuid,integer) TO service_role;
REVOKE ALL ON FUNCTION public.decide_station_catalogue_review(uuid,text,uuid,text,text,timestamptz) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.decide_station_catalogue_review(uuid,text,uuid,text,text,timestamptz) TO service_role;