-- Path N compatibility for migration 020 (DO NOT use on Path H hosted upgrades in place of 020).
-- Target original: database/migrations/020_authority_membership_and_permission_grant_lifecycle.sql
-- Conflict: Path N baseline already defines permission_grants.authority_id.
-- This patch skips ADD COLUMN authority_id and applies remaining 020 objects idempotently where possible.
-- Detection: authority_id column already present on permission_grants.
-- Path H: continue to apply original 020 when authority_id is absent.

CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE SCHEMA IF NOT EXISTS private;


-- Ensure FK and NOT NULL only when safe (empty or already populated)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='permission_grants' AND column_name='authority_id'
  ) THEN
    -- Add FK if missing
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname = 'permission_grants_authority_fk'
    ) THEN
      ALTER TABLE public.permission_grants
        ADD CONSTRAINT permission_grants_authority_fk
        FOREIGN KEY (authority_id) REFERENCES public.meteorological_authorities(id) ON DELETE RESTRICT;
    END IF;
    -- Match original 020 end-state: NOT NULL when safe (empty Path N has no nulls).
    IF EXISTS (SELECT 1 FROM public.permission_grants WHERE authority_id IS NULL) THEN
      RAISE EXCEPTION 'permission_grants_authority_backfill_required';
    END IF;
    ALTER TABLE public.permission_grants ALTER COLUMN authority_id SET NOT NULL;
  ELSE
    RAISE EXCEPTION 'path_n_020_requires_baseline_authority_id';
  END IF;
END $$;

INSERT INTO public.metra_role_permissions(role_code,permission_code) VALUES('system_admin','authority.access.review'),('system_admin','authority.access.revoke') ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS public.authority_access_audit_events(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,target_kind text NOT NULL CHECK(target_kind IN('membership','permission_grant')),target_id uuid NOT NULL,authority_id uuid NOT NULL REFERENCES public.meteorological_authorities(id) ON DELETE RESTRICT,subject_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,action_code text NOT NULL CHECK(action_code IN('requested','approved','rejected','revoked')),from_status text,to_status text NOT NULL,reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 5 AND 2000),metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK(jsonb_typeof(metadata)='object'),occurred_at timestamptz NOT NULL,created_at timestamptz NOT NULL DEFAULT clock_timestamp());
CREATE INDEX IF NOT EXISTS authority_access_audit_authority_time_idx ON public.authority_access_audit_events(authority_id,occurred_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS authority_access_audit_subject_time_idx ON public.authority_access_audit_events(subject_user_id,occurred_at DESC,id DESC);
ALTER TABLE public.authority_access_audit_events ENABLE ROW LEVEL SECURITY; ALTER TABLE public.authority_access_audit_events FORCE ROW LEVEL SECURITY;
CREATE POLICY authority_access_audit_deny_clients ON public.authority_access_audit_events FOR ALL TO anon,authenticated USING(false) WITH CHECK(false);
REVOKE ALL ON public.authority_access_audit_events FROM PUBLIC,anon,authenticated; GRANT SELECT ON public.authority_access_audit_events TO service_role;
GRANT USAGE,SELECT ON SEQUENCE public.authority_access_audit_events_id_seq TO service_role;
CREATE OR REPLACE FUNCTION private.reject_authority_access_audit_mutation() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$ BEGIN RAISE EXCEPTION 'authority_access_audit_is_append_only' USING ERRCODE='42501'; END $$;
CREATE TRIGGER authority_access_audit_append_only BEFORE UPDATE OR DELETE OR TRUNCATE ON public.authority_access_audit_events FOR EACH STATEMENT EXECUTE FUNCTION private.reject_authority_access_audit_mutation();
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.authority_memberships,public.permission_grants FROM service_role; GRANT SELECT ON public.authority_memberships,public.permission_grants TO service_role;
CREATE OR REPLACE FUNCTION public.metra_user_has_authority_permission(p_user_id uuid, p_authority_id uuid, p_permission_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
 SELECT COALESCE(EXISTS(
  SELECT 1 FROM public.metra_account_states ac
  JOIN public.meteorological_authorities a ON a.id=p_authority_id
  JOIN public.countries c ON c.id=a.country_id
  JOIN public.authority_memberships m ON m.user_id=ac.user_id AND m.authority_id=a.id
  JOIN public.metra_role_catalogue r ON r.role_code=m.membership_role_code AND r.is_active
  JOIN public.metra_role_permissions rp ON rp.role_code=r.role_code AND rp.permission_code=p_permission_code
  JOIN public.permission_grants g ON g.user_id=ac.user_id AND g.authority_id=a.id AND g.permission_code=p_permission_code
  WHERE ac.user_id=p_user_id AND ac.account_state='active' AND a.is_active AND c.is_active
   AND m.approval_status='approved' AND m.valid_from<=statement_timestamp()
   AND(m.valid_to IS NULL OR m.valid_to>statement_timestamp())
   AND g.approval_status='approved' AND g.revoked_at IS NULL AND g.valid_from<=statement_timestamp()
   AND(g.valid_to IS NULL OR g.valid_to>statement_timestamp())
 ),false);
$function$
;

CREATE OR REPLACE FUNCTION public.metra_user_has_station_permission(p_user_id uuid, p_station_id uuid, p_permission_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
 SELECT COALESCE(EXISTS(
  SELECT 1 FROM public.metra_account_states ac
  JOIN public.station_catalogue s ON s.id=p_station_id
  JOIN public.meteorological_authorities a ON a.id=s.owner_authority_id AND a.country_id=s.country_id
  JOIN public.countries c ON c.id=s.country_id
  JOIN public.authority_memberships m ON m.user_id=ac.user_id AND m.authority_id=s.owner_authority_id
  JOIN public.station_assignments sa ON sa.user_id=ac.user_id AND sa.station_id=s.id AND sa.authority_id=s.owner_authority_id
  JOIN public.metra_role_catalogue r ON r.role_code=sa.assignment_role_code AND r.is_active
  JOIN public.metra_role_permissions rp ON rp.role_code=r.role_code AND rp.permission_code=p_permission_code
  JOIN public.permission_grants g ON g.user_id=ac.user_id AND g.authority_id=s.owner_authority_id AND g.permission_code=p_permission_code
  WHERE ac.user_id=p_user_id AND ac.account_state='active' AND s.approval_status='approved'
   AND s.operational_status='active' AND s.is_demo=false AND a.is_active AND c.is_active
   AND m.approval_status='approved' AND m.valid_from<=statement_timestamp()
   AND(m.valid_to IS NULL OR m.valid_to>statement_timestamp())
   AND sa.approval_status='approved' AND sa.valid_from<=statement_timestamp()
   AND(sa.valid_to IS NULL OR sa.valid_to>statement_timestamp())
   AND g.approval_status='approved' AND g.revoked_at IS NULL AND g.valid_from<=statement_timestamp()
   AND(g.valid_to IS NULL OR g.valid_to>statement_timestamp())
 ),false);
$function$
;

CREATE OR REPLACE FUNCTION public.decide_metra_registration_for_station(p_request_id uuid, p_station_id uuid, p_expected_status text, p_actor_user_id uuid, p_decision text, p_note text, p_occurred_at timestamp with time zone)
 RETURNS TABLE(result_status text, resulting_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE v_authority_id uuid; v_requested_station_id uuid; v_now timestamptz:=clock_timestamp();
BEGIN
 IF p_request_id IS NULL OR p_station_id IS NULL OR p_actor_user_id IS NULL
  OR p_actor_user_id='00000000-0000-0000-0000-000000000000'::uuid
  OR p_expected_status IS NULL OR p_expected_status NOT IN('pending_station_approval','pending_system_approval')
  OR p_decision IS NULL OR p_decision NOT IN('approve','reject') OR p_occurred_at IS NULL
  OR(p_note IS NOT NULL AND(length(p_note)>2000 OR p_note~'[[:cntrl:]]'))
  OR(p_decision='reject' AND nullif(trim(p_note),'') IS NULL)
 THEN RAISE EXCEPTION 'invalid_registration_decision_request' USING ERRCODE='22023'; END IF;
 SELECT requested_station_id INTO v_requested_station_id FROM public.registration_requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND THEN RETURN QUERY SELECT 'not_found'::text,NULL::text; RETURN; END IF;
 IF v_requested_station_id IS DISTINCT FROM p_station_id THEN RETURN QUERY SELECT 'unauthorized'::text,NULL::text; RETURN; END IF;
 IF p_expected_status='pending_system_approval' THEN
  SELECT s.owner_authority_id INTO v_authority_id FROM public.station_catalogue s
   JOIN public.meteorological_authorities a ON a.id=s.owner_authority_id AND a.country_id=s.country_id
   JOIN public.countries c ON c.id=s.country_id
   WHERE s.id=p_station_id AND s.is_demo=false AND s.approval_status='approved'
    AND s.operational_status='active' AND a.is_active AND c.is_active FOR SHARE OF s,a,c;
  IF v_authority_id IS NULL THEN RETURN QUERY SELECT 'unauthorized'::text,NULL::text; RETURN; END IF;
  PERFORM 1 FROM public.metra_account_states a WHERE a.user_id=p_actor_user_id AND a.account_state='active' FOR SHARE;
  IF NOT FOUND THEN RETURN QUERY SELECT 'unauthorized'::text,NULL::text; RETURN; END IF;
  PERFORM 1 FROM public.authority_memberships m
   JOIN public.metra_role_catalogue r ON r.role_code=m.membership_role_code AND r.is_active
   JOIN public.metra_role_permissions rp ON rp.role_code=r.role_code AND rp.permission_code='registrations.system.approve'
   WHERE m.user_id=p_actor_user_id AND m.authority_id=v_authority_id AND m.approval_status='approved'
    AND m.valid_from<=v_now AND(m.valid_to IS NULL OR m.valid_to>v_now) FOR SHARE OF m,r,rp;
  IF NOT FOUND THEN RETURN QUERY SELECT 'unauthorized'::text,NULL::text; RETURN; END IF;
  PERFORM 1 FROM public.permission_grants g WHERE g.user_id=p_actor_user_id
   AND g.authority_id=v_authority_id AND g.permission_code='registrations.system.approve'
   AND g.approval_status='approved' AND g.revoked_at IS NULL AND g.valid_from<=v_now
   AND(g.valid_to IS NULL OR g.valid_to>v_now) FOR SHARE;
  IF NOT FOUND THEN RETURN QUERY SELECT 'unauthorized'::text,NULL::text; RETURN; END IF;
 END IF;
 RETURN QUERY SELECT d.result_status,d.resulting_status FROM public.decide_metra_registration(
  p_request_id,p_expected_status,p_actor_user_id,p_decision,p_note,p_occurred_at)d;
END $function$
;

CREATE OR REPLACE FUNCTION public.request_authority_membership(p_user_id uuid, p_authority_id uuid, p_role_code text, p_requested_by uuid, p_reason text, p_valid_from timestamp with time zone DEFAULT clock_timestamp(), p_valid_to timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE v_requestable boolean; v_id uuid; v_now timestamptz:=clock_timestamp();
BEGIN
 IF p_user_id IS NULL OR p_authority_id IS NULL OR p_requested_by IS NULL OR p_role_code IS NULL
  OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 2000 OR p_reason~'[[:cntrl:]]'
  OR p_valid_from IS NULL OR(p_valid_to IS NOT NULL AND p_valid_to<=p_valid_from)
 THEN RAISE EXCEPTION 'invalid_authority_membership_request' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM public.meteorological_authorities a JOIN public.countries c ON c.id=a.country_id
  WHERE a.id=p_authority_id AND a.is_active AND c.is_active FOR SHARE OF a,c;
 IF NOT FOUND THEN RAISE EXCEPTION 'authority_unavailable' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.metra_account_states s WHERE s.user_id=p_user_id AND s.account_state='active' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'membership_subject_not_active' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.metra_account_states s WHERE s.user_id=p_requested_by AND s.account_state='active' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'membership_requester_not_active' USING ERRCODE='42501'; END IF;
 SELECT is_requestable INTO v_requestable FROM public.metra_role_catalogue WHERE role_code=p_role_code AND is_active FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'membership_role_unavailable' USING ERRCODE='22023'; END IF;
 IF p_user_id=p_requested_by THEN
  IF NOT v_requestable THEN RAISE EXCEPTION 'role_requires_privileged_sponsorship' USING ERRCODE='42501'; END IF;
 ELSE
  IF NOT public.metra_user_has_authority_permission(p_requested_by,p_authority_id,'authority.access.review')
   THEN RAISE EXCEPTION 'membership_sponsorship_forbidden' USING ERRCODE='42501'; END IF;
 END IF;
 INSERT INTO public.authority_memberships(user_id,authority_id,membership_role_code,approval_status,valid_from,valid_to,requested_by,reason)
 VALUES(p_user_id,p_authority_id,p_role_code,'pending',p_valid_from,p_valid_to,p_requested_by,btrim(p_reason)) RETURNING id INTO v_id;
 INSERT INTO public.authority_access_audit_events(target_kind,target_id,authority_id,subject_user_id,actor_user_id,action_code,from_status,to_status,reason,occurred_at)
 VALUES('membership',v_id,p_authority_id,p_user_id,p_requested_by,'requested',NULL,'pending',btrim(p_reason),v_now);
 RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.decide_authority_membership(p_membership_id uuid, p_actor_user_id uuid, p_decision text, p_reason text, p_occurred_at timestamp with time zone DEFAULT clock_timestamp())
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
DECLARE v public.authority_memberships%ROWTYPE; n timestamptz:=clock_timestamp();
BEGIN
 IF p_membership_id IS NULL OR p_actor_user_id IS NULL OR p_decision IS NULL OR p_decision NOT IN('approve','reject')
  OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 2000 OR p_reason~'[[:cntrl:]]' OR p_occurred_at IS NULL
 THEN RAISE EXCEPTION 'invalid_authority_membership_decision' USING ERRCODE='22023'; END IF;
 SELECT * INTO v FROM public.authority_memberships WHERE id=p_membership_id FOR UPDATE;
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
REVOKE ALL ON FUNCTION public.metra_user_has_authority_permission(uuid,uuid,text) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.metra_user_has_authority_permission(uuid,uuid,text) TO service_role;
REVOKE ALL ON FUNCTION public.metra_user_has_station_permission(uuid,uuid,text) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.metra_user_has_station_permission(uuid,uuid,text) TO service_role;
REVOKE ALL ON FUNCTION public.decide_metra_registration_for_station(uuid,uuid,text,uuid,text,text,timestamptz) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.decide_metra_registration_for_station(uuid,uuid,text,uuid,text,text,timestamptz) TO service_role;
REVOKE ALL ON FUNCTION public.request_authority_membership(uuid,uuid,text,uuid,text,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.request_authority_membership(uuid,uuid,text,uuid,text,timestamptz,timestamptz) TO service_role;
REVOKE ALL ON FUNCTION public.decide_authority_membership(uuid,uuid,text,text,timestamptz) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.decide_authority_membership(uuid,uuid,text,text,timestamptz) TO service_role;
REVOKE ALL ON FUNCTION public.revoke_authority_membership(uuid,uuid,text,timestamptz) FROM PUBLIC,anon,authenticated; GRANT EXECUTE ON FUNCTION public.revoke_authority_membership(uuid,uuid,text,timestamptz) TO service_role;