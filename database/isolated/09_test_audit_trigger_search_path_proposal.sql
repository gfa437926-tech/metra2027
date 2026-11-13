DO $test$
DECLARE
  v_count integer;
  v_definer_count integer;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE p.prosecdef)
    INTO v_count, v_definer_count
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'reject_metra_equipment_fault_audit_mutation',
      'reject_metra_support_incident_audit_mutation'
    )
    AND p.proconfig @> ARRAY['search_path=pg_catalog'];

  IF v_count <> 2 THEN
    RAISE EXCEPTION 'expected both audit trigger functions to pin search_path, got %', v_count;
  END IF;
  IF v_definer_count <> 0 THEN
    RAISE EXCEPTION 'audit trigger guards must remain SECURITY INVOKER';
  END IF;
END;
$test$;
