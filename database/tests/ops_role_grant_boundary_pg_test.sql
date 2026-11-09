-- Least-privilege grant boundary test for the NEW METRA disposable PostgreSQL CI DB.
-- Never run against hosted Supabase or the legacy database.
\set ON_ERROR_STOP on

DO $$
DECLARE
  v_role record;
BEGIN
  IF current_database() <> 'metra_ops_test' THEN
    RAISE EXCEPTION 'REFUSED: expected metra_ops_test, got %', current_database();
  END IF;

  SELECT rolcanlogin, rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls
    INTO v_role FROM pg_roles WHERE rolname = 'metra_api_runtime';
  IF NOT FOUND OR v_role.rolcanlogin OR v_role.rolsuper OR v_role.rolcreatedb
     OR v_role.rolcreaterole OR v_role.rolreplication OR v_role.rolbypassrls THEN
    RAISE EXCEPTION 'metra_api_runtime must be a constrained NOLOGIN, non-superuser, non-BYPASSRLS role';
  END IF;

  SELECT rolcanlogin, rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls
    INTO v_role FROM pg_roles WHERE rolname = 'metra_ops_faults';
  IF NOT FOUND OR v_role.rolcanlogin OR v_role.rolsuper OR v_role.rolcreatedb
     OR v_role.rolcreaterole OR v_role.rolreplication OR v_role.rolbypassrls THEN
    RAISE EXCEPTION 'metra_ops_faults must be a constrained NOLOGIN, non-superuser, non-BYPASSRLS role';
  END IF;

  IF NOT pg_has_role('metra_api_runtime', 'metra_ops_faults', 'MEMBER') THEN
    RAISE EXCEPTION 'metra_api_runtime must be a member of metra_ops_faults';
  END IF;

  IF has_table_privilege('anon', 'public.metra_equipment_faults', 'SELECT')
     OR has_table_privilege('authenticated', 'public.metra_equipment_faults', 'SELECT')
     OR has_table_privilege('anon', 'public.metra_support_incidents', 'SELECT')
     OR has_table_privilege('authenticated', 'public.metra_support_incidents', 'SELECT') THEN
    RAISE EXCEPTION 'client roles must not read operational tables directly';
  END IF;

  IF NOT has_table_privilege('metra_ops_faults', 'public.metra_equipment_faults', 'SELECT')
     OR NOT has_table_privilege('metra_ops_faults', 'public.metra_equipment_faults', 'INSERT')
     OR NOT has_column_privilege('metra_ops_faults', 'public.metra_equipment_faults', 'status', 'UPDATE')
     OR NOT has_column_privilege('metra_ops_faults', 'public.metra_equipment_faults', 'assigned_to', 'UPDATE')
     OR NOT has_column_privilege('metra_ops_faults', 'public.metra_equipment_faults', 'progress_percent', 'UPDATE')
     OR NOT has_column_privilege('metra_ops_faults', 'public.metra_equipment_faults', 'progress_note', 'UPDATE')
     OR NOT has_column_privilege('metra_ops_faults', 'public.metra_equipment_faults', 'updated_at', 'UPDATE')
     OR has_column_privilege('metra_ops_faults', 'public.metra_equipment_faults', 'reporter_user_id', 'UPDATE')
     OR has_column_privilege('metra_ops_faults', 'public.metra_equipment_faults', 'station_id', 'UPDATE')
     OR has_column_privilege('metra_ops_faults', 'public.metra_equipment_faults', 'created_at', 'UPDATE')
     OR has_table_privilege('metra_ops_faults', 'public.metra_equipment_faults', 'DELETE') THEN
    RAISE EXCEPTION 'equipment fault grants exceed or fail the approved column-level boundary';
  END IF;

  IF NOT has_table_privilege('metra_ops_faults', 'public.metra_support_incidents', 'SELECT')
     OR NOT has_table_privilege('metra_ops_faults', 'public.metra_support_incidents', 'INSERT')
     OR NOT has_column_privilege('metra_ops_faults', 'public.metra_support_incidents', 'status', 'UPDATE')
     OR NOT has_column_privilege('metra_ops_faults', 'public.metra_support_incidents', 'assigned_to', 'UPDATE')
     OR NOT has_column_privilege('metra_ops_faults', 'public.metra_support_incidents', 'updated_at', 'UPDATE')
     OR has_column_privilege('metra_ops_faults', 'public.metra_support_incidents', 'reporter_user_id', 'UPDATE')
     OR has_column_privilege('metra_ops_faults', 'public.metra_support_incidents', 'station_id', 'UPDATE')
     OR has_column_privilege('metra_ops_faults', 'public.metra_support_incidents', 'created_at', 'UPDATE')
     OR has_table_privilege('metra_ops_faults', 'public.metra_support_incidents', 'DELETE') THEN
    RAISE EXCEPTION 'support incident grants exceed or fail the approved column-level boundary';
  END IF;

  IF NOT has_table_privilege('metra_ops_faults', 'public.metra_equipment_fault_audit_events', 'SELECT')
     OR NOT has_table_privilege('metra_ops_faults', 'public.metra_equipment_fault_audit_events', 'INSERT')
     OR has_table_privilege('metra_ops_faults', 'public.metra_equipment_fault_audit_events', 'UPDATE')
     OR has_table_privilege('metra_ops_faults', 'public.metra_equipment_fault_audit_events', 'DELETE')
     OR NOT has_table_privilege('metra_ops_faults', 'public.metra_support_incident_audit_events', 'SELECT')
     OR NOT has_table_privilege('metra_ops_faults', 'public.metra_support_incident_audit_events', 'INSERT')
     OR has_table_privilege('metra_ops_faults', 'public.metra_support_incident_audit_events', 'UPDATE')
     OR has_table_privilege('metra_ops_faults', 'public.metra_support_incident_audit_events', 'DELETE') THEN
    RAISE EXCEPTION 'audit grants must remain read/insert only';
  END IF;

  IF NOT has_sequence_privilege('metra_ops_faults', 'public.metra_equipment_fault_audit_events_id_seq', 'USAGE')
     OR NOT has_sequence_privilege('metra_ops_faults', 'public.metra_support_incident_audit_events_id_seq', 'USAGE')
     OR has_sequence_privilege('anon', 'public.metra_equipment_fault_audit_events_id_seq', 'USAGE')
     OR has_sequence_privilege('authenticated', 'public.metra_equipment_fault_audit_events_id_seq', 'USAGE') THEN
    RAISE EXCEPTION 'operational audit sequence grants exceed or fail the intended boundary';
  END IF;

  RAISE NOTICE 'ops_role_grant_boundary_pg_test: PASS';
END $$;
