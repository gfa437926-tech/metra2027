DO $$
DECLARE
  unsafe_functions text[];
BEGIN
  SELECT array_agg(n.nspname || '.' || p.proname ORDER BY n.nspname,p.proname)
  INTO unsafe_functions
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE (n.nspname,p.proname) IN (
    ('public','reject_metra_observation_audit_mutation'),
    ('public','reject_metra_equipment_fault_audit_mutation'),
    ('public','reject_metra_support_incident_audit_mutation'),
    ('private','reject_authority_access_audit_mutation')
  )
  AND NOT COALESCE(p.proconfig @> ARRAY['search_path=pg_catalog']::text[], false);

  IF unsafe_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Audit trigger functions have unsafe or unset search_path: %',
      array_to_string(unsafe_functions, ', ');
  END IF;
END
$$;
