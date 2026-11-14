DO '
BEGIN
  IF NOT has_schema_privilege(''metra_api_runtime'',''private'',''USAGE'') THEN RAISE EXCEPTION ''missing private USAGE''; END IF;
  IF NOT has_table_privilege(''metra_api_runtime'',''public.station_catalogue'',''SELECT'') THEN RAISE EXCEPTION ''missing runtime station SELECT''; END IF;
  IF has_table_privilege(''metra_api_runtime'',''public.station_catalogue'',''INSERT'') THEN RAISE EXCEPTION ''unexpected runtime station INSERT''; END IF;
  IF NOT has_table_privilege(''service_role'',''public.station_catalogue'',''INSERT'') THEN RAISE EXCEPTION ''missing service_role table INSERT''; END IF;
  IF has_table_privilege(''service_role'',''public.authority_access_audit_events'',''INSERT'') THEN RAISE EXCEPTION ''unexpected service_role audit INSERT''; END IF;
  IF has_table_privilege(''anon'',''public.station_catalogue'',''SELECT'') THEN RAISE EXCEPTION ''unexpected anon table SELECT''; END IF;
  IF NOT has_sequence_privilege(''anon'',''public.station_audit_log_id_seq'',''SELECT'') THEN RAISE EXCEPTION ''missing anon sequence SELECT''; END IF;
  IF NOT has_sequence_privilege(''anon'',''public.station_audit_log_id_seq'',''UPDATE'') THEN RAISE EXCEPTION ''missing anon sequence UPDATE''; END IF;
  IF NOT has_function_privilege(''anon'',''public.reject_metra_equipment_fault_audit_mutation()'',''EXECUTE'') THEN RAISE EXCEPTION ''missing anon trigger function EXECUTE''; END IF;
  IF NOT has_function_privilege(''anon'',''private.reject_authority_access_audit_mutation()'',''EXECUTE'') THEN RAISE EXCEPTION ''missing PUBLIC private trigger function EXECUTE''; END IF;
  IF has_function_privilege(''service_role'',''public.reject_metra_observation_audit_mutation()'',''EXECUTE'') THEN RAISE EXCEPTION ''unexpected service_role observation audit EXECUTE''; END IF;
  IF NOT has_function_privilege(''service_role'',''public.get_authority_catalogue()'',''EXECUTE'') THEN RAISE EXCEPTION ''missing service_role RPC EXECUTE''; END IF;
  IF NOT has_function_privilege(''metra_api_runtime'',''private.decide_metra_registration(uuid,text,uuid,text,text,timestamp with time zone)'',''EXECUTE'') THEN RAISE EXCEPTION ''missing private runtime EXECUTE''; END IF;
  IF has_schema_privilege(''service_role'',''private'',''USAGE'') THEN RAISE EXCEPTION ''unexpected service_role private schema USAGE''; END IF;
  IF NOT pg_has_role(''postgres'',''metra_api_runtime'',''MEMBER'') THEN RAISE EXCEPTION ''postgres is not a member of runtime role''; END IF;
END
';
