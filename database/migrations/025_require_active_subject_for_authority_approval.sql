CREATE OR REPLACE FUNCTION public.decide_authority_membership(p_membership_id uuid, p_authority_id uuid, p_actor_user_id uuid, p_decision text, p_reason text, p_occurred_at timestamp with time zone DEFAULT clock_timestamp())
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE v public.authority_memberships%ROWTYPE; n timestamptz:=clock_timestamp();
BEGIN
 IF p_membership_id IS NULL OR p_authority_id IS NULL OR p_actor_user_id IS NULL OR p_decision IS NULL OR p_decision NOT IN('approve','reject')
  OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 2000 OR p_reason~'[[:cntrl:]]' OR p_occurred_at IS NULL
 THEN RAISE EXCEPTION 'invalid_authority_membership_decision' USING ERRCODE='22023'; END IF;
 SELECT * INTO v FROM public.authority_memberships WHERE id=p_membership_id FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF v.authority_id IS DISTINCT FROM p_authority_id THEN RETURN 'unauthorized'; END IF;
 IF v.approval_status<>'pending' THEN RETURN 'conflict'; END IF;
 PERFORM 1 FROM public.metra_account_states s WHERE s.user_id=v.user_id AND s.account_state='active' FOR SHARE;
 IF NOT FOUND THEN RETURN 'conflict'; END IF;
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
 UPDATE public.authority_memberships SET approval_status=CASE p_decision WHEN 'approve' THEN 'approved' ELSE 'rejected' END,
  approved_by=p_actor_user_id,reviewed_at=p_occurred_at WHERE id=p_membership_id AND approval_status='pending';
 IF NOT FOUND THEN RETURN 'conflict'; END IF;
 INSERT INTO public.authority_access_audit_events(target_kind,target_id,authority_id,subject_user_id,actor_user_id,action_code,from_status,to_status,reason,occurred_at)
 VALUES('membership',p_membership_id,v.authority_id,v.user_id,p_actor_user_id,
  CASE p_decision WHEN 'approve' THEN 'approved' ELSE 'rejected' END,'pending',
  CASE p_decision WHEN 'approve' THEN 'approved' ELSE 'rejected' END,btrim(p_reason),p_occurred_at);
 RETURN 'committed';
END $function$
;

CREATE OR REPLACE FUNCTION public.decide_authority_permission_grant(p_grant_id uuid, p_authority_id uuid, p_actor_user_id uuid, p_decision text, p_reason text, p_occurred_at timestamp with time zone DEFAULT clock_timestamp())
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE v public.permission_grants%ROWTYPE; n timestamptz:=clock_timestamp();
BEGIN
 IF p_grant_id IS NULL OR p_authority_id IS NULL OR p_actor_user_id IS NULL OR p_decision IS NULL OR p_decision NOT IN('approve','reject')
  OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 2000 OR p_reason~'[[:cntrl:]]'
  OR p_occurred_at IS NULL THEN RAISE EXCEPTION 'invalid_authority_permission_decision' USING ERRCODE='22023'; END IF;
 SELECT * INTO v FROM public.permission_grants WHERE id=p_grant_id FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF v.authority_id IS DISTINCT FROM p_authority_id THEN RETURN 'unauthorized'; END IF;
 IF v.approval_status<>'pending' THEN RETURN 'conflict'; END IF;
 PERFORM 1 FROM public.metra_account_states s WHERE s.user_id=v.user_id AND s.account_state='active' FOR SHARE;
 IF NOT FOUND THEN RETURN 'conflict'; END IF;
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