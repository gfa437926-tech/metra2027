CREATE INDEX authority_access_audit_actor_time_idx ON public.authority_access_audit_events(actor_user_id,occurred_at DESC,id DESC);
ALTER TABLE public.permission_grants DROP CONSTRAINT permission_grants_revocation_check;
ALTER TABLE public.permission_grants ADD CONSTRAINT permission_grants_revocation_check CHECK(revoked_at IS NULL OR revoked_at>=created_at);
CREATE OR REPLACE FUNCTION public.revoke_authority_membership(p_membership_id uuid, p_actor_user_id uuid, p_reason text, p_occurred_at timestamp with time zone DEFAULT clock_timestamp())
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE v public.authority_memberships%ROWTYPE; n timestamptz:=clock_timestamp();
BEGIN
 IF p_membership_id IS NULL OR p_actor_user_id IS NULL OR p_reason IS NULL
  OR length(btrim(p_reason)) NOT BETWEEN 5 AND 2000 OR p_reason~'[[:cntrl:]]' OR p_occurred_at IS NULL
 THEN RAISE EXCEPTION 'invalid_authority_membership_revocation' USING ERRCODE='22023'; END IF;
 SELECT * INTO v FROM public.authority_memberships WHERE id=p_membership_id FOR UPDATE;
 IF NOT FOUND THEN RETURN 'not_found'; END IF;
 IF v.approval_status<>'approved' THEN RETURN 'conflict'; END IF;
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
 UPDATE public.authority_memberships SET approval_status='revoked' WHERE id=p_membership_id AND approval_status='approved';
 WITH revoked AS (
  UPDATE public.permission_grants SET approval_status='revoked',revoked_at=GREATEST(clock_timestamp(),created_at)
   WHERE user_id=v.user_id AND authority_id=v.authority_id AND approval_status='approved' AND revoked_at IS NULL
   RETURNING id,permission_code
 )
 INSERT INTO public.authority_access_audit_events(target_kind,target_id,authority_id,subject_user_id,actor_user_id,action_code,from_status,to_status,reason,metadata,occurred_at)
 SELECT 'permission_grant',id,v.authority_id,v.user_id,p_actor_user_id,'revoked','approved','revoked',
  btrim(p_reason),jsonb_build_object('permission_code',permission_code,'cause','membership_revoked'),p_occurred_at FROM revoked;
 INSERT INTO public.authority_access_audit_events(target_kind,target_id,authority_id,subject_user_id,actor_user_id,action_code,from_status,to_status,reason,occurred_at)
 VALUES('membership',p_membership_id,v.authority_id,v.user_id,p_actor_user_id,'revoked','approved','revoked',btrim(p_reason),p_occurred_at);
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
REVOKE ALL ON FUNCTION public.revoke_authority_membership(uuid,uuid,text,timestamptz) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.revoke_authority_membership(uuid,uuid,text,timestamptz) TO service_role;
REVOKE ALL ON FUNCTION public.revoke_authority_permission_grant(uuid,uuid,text,timestamptz) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.revoke_authority_permission_grant(uuid,uuid,text,timestamptz) TO service_role;