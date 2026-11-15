\set ON_ERROR_STOP on
BEGIN;

INSERT INTO iam.organizations(id,organization_state) VALUES
 ('10000000-0000-0000-0000-000000000001','active'),
 ('20000000-0000-0000-0000-000000000002','active');
INSERT INTO iam.user_profiles(user_id,profile_state) VALUES
 ('00000000-0000-0000-0000-000000000001','active'),
 ('00000000-0000-0000-0000-000000000002','active'),
 ('00000000-0000-0000-0000-000000000003','active'),
 ('00000000-0000-0000-0000-000000000004','suspended'),
 ('00000000-0000-0000-0000-000000000005','active'),
 ('00000000-0000-0000-0000-000000000099','active');
INSERT INTO iam.memberships(id,user_id,organization_id,membership_state,valid_from,approved_at,approved_by) VALUES
 ('11000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','active',now()-interval '1 day',now()-interval '1 day','00000000-0000-0000-0000-000000000099'),
 ('11000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','active',now()-interval '1 day',now()-interval '1 day','00000000-0000-0000-0000-000000000099'),
 ('11000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','active',now()-interval '1 day',now()-interval '1 day','00000000-0000-0000-0000-000000000099'),
 ('11000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001','active',now()-interval '1 day',now()-interval '1 day','00000000-0000-0000-0000-000000000099'),
 ('11000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000002','active',now()-interval '1 day',now()-interval '1 day','00000000-0000-0000-0000-000000000099');
INSERT INTO catalog.station_types(id,type_code,name_ar,name_en,is_active) VALUES
 ('30000000-0000-0000-0000-000000000001','synoptic','مرصد سينوبتيكي','Synoptic',true),
 ('30000000-0000-0000-0000-000000000002','automatic','محطة آلية','Automatic',false);
INSERT INTO catalog.stations(id,owner_organization_id,station_type_id,station_code,name_ar,name_en,approval_status,operational_status) VALUES
 ('40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','STA-A','محطة ألف','Station A','approved','active'),
 ('40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','STA-B','محطة باء','Station B','approved','active'),
 ('40000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','STA-C','محطة جيم','Station C','approved','temporarily_closed'),
 ('40000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','STA-D','محطة دال','Station D','pending','active'),
 ('40000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','STA-E','محطة هاء','Station E','approved','inactive'),
 ('40000000-0000-0000-0000-000000000006','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','STA-F','محطة واو','Station F','approved','active');
INSERT INTO catalog.station_locations(station_id,latitude,longitude,location_source) VALUES
 ('40000000-0000-0000-0000-000000000001',33.500000,36.300000,'verified_manual'),
 ('40000000-0000-0000-0000-000000000002',34.000000,36.500000,'verified_manual');
INSERT INTO iam.role_assignments(membership_id,organization_id,station_id,role_id,scope_type,assignment_state,valid_from,assigned_by) VALUES
 ('11000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',(SELECT id FROM iam.roles WHERE role_code='station_manager'),'station','active',now()-interval '1 day','00000000-0000-0000-0000-000000000099'),
 ('11000000-0000-0000-0000-000000000002',NULL,NULL,(SELECT id FROM iam.roles WHERE role_code='auditor'),'global','active',now()-interval '1 day','00000000-0000-0000-0000-000000000099'),
 ('11000000-0000-0000-0000-000000000003',NULL,NULL,(SELECT id FROM iam.roles WHERE role_code='network_department_head'),'global','active',now()-interval '1 day','00000000-0000-0000-0000-000000000099'),
 ('11000000-0000-0000-0000-000000000004',NULL,NULL,(SELECT id FROM iam.roles WHERE role_code='auditor'),'global','active',now()-interval '1 day','00000000-0000-0000-0000-000000000099'),
 ('11000000-0000-0000-0000-000000000005',NULL,NULL,(SELECT id FROM iam.roles WHERE role_code='auditor'),'global','expired',now()-interval '2 days','00000000-0000-0000-0000-000000000099');
UPDATE iam.role_assignments SET valid_to=now()-interval '1 hour' WHERE membership_id='11000000-0000-0000-0000-000000000005';

DO $$
DECLARE v_codes text[];
BEGIN
  SELECT array_agg(item->>'station_code' ORDER BY item->>'station_code') INTO v_codes
  FROM public.get_station_directory_for_actor('00000000-0000-0000-0000-000000000001',500,0,NULL) item;
  IF v_codes IS DISTINCT FROM ARRAY['STA-A']::text[] THEN RAISE EXCEPTION 'station_user_cross_station_isolation_failed: %',v_codes; END IF;

  SELECT array_agg(item->>'station_code' ORDER BY item->>'station_code') INTO v_codes
  FROM public.get_station_directory_for_actor('00000000-0000-0000-0000-000000000002',500,0,NULL) item;
  IF v_codes IS DISTINCT FROM ARRAY['STA-A','STA-B','STA-C']::text[] THEN RAISE EXCEPTION 'auditor_global_read_or_approval_filter_failed: %',v_codes; END IF;

  SELECT array_agg(item->>'station_code' ORDER BY item->>'station_code') INTO v_codes
  FROM public.get_station_directory_for_actor('00000000-0000-0000-0000-000000000003',500,0,NULL) item;
  IF v_codes IS DISTINCT FROM ARRAY['STA-A','STA-B','STA-C']::text[] THEN RAISE EXCEPTION 'network_head_global_read_failed: %',v_codes; END IF;

  SELECT array_agg(item->>'station_code' ORDER BY item->>'station_code') INTO v_codes
  FROM public.get_station_directory_for_actor('00000000-0000-0000-0000-000000000004',500,0,NULL) item;
  IF v_codes IS NOT NULL THEN RAISE EXCEPTION 'suspended_profile_was_authorized'; END IF;

  SELECT array_agg(item->>'station_code' ORDER BY item->>'station_code') INTO v_codes
  FROM public.get_station_directory_for_actor('00000000-0000-0000-0000-000000000005',500,0,NULL) item;
  IF v_codes IS NOT NULL THEN RAISE EXCEPTION 'expired_assignment_was_authorized'; END IF;

  IF has_function_privilege('anon','public.get_station_directory_for_actor(uuid,integer,integer,text)','EXECUTE')
     OR has_function_privilege('authenticated','public.get_station_directory_for_actor(uuid,integer,integer,text)','EXECUTE')
     OR NOT has_function_privilege('service_role','public.get_station_directory_for_actor(uuid,integer,integer,text)','EXECUTE') THEN
    RAISE EXCEPTION 'station_directory_rpc_execute_acl_invalid';
  END IF;
END $$;

DO $$ BEGIN
  PERFORM * FROM public.get_station_directory_for_actor('00000000-0000-0000-0000-000000000002',501,0,NULL);
  RAISE EXCEPTION 'invalid_limit_was_accepted';
EXCEPTION WHEN invalid_parameter_value THEN NULL; END $$;

ROLLBACK;
