-- Reapply ACLs excluded by pg_dump --no-privileges.
-- The exact source ACL inventory is recorded in 06_runtime_role_inventory.txt.

-- Supabase server role: full table access except three deliberately read-only tables.
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
REVOKE ALL PRIVILEGES ON TABLE
  public.authority_access_audit_events,
  public.authority_memberships,
  public.permission_grants
FROM service_role;
GRANT SELECT ON TABLE
  public.authority_access_audit_events,
  public.authority_memberships,
  public.permission_grants
TO service_role;

-- Runtime role is non-login, NO BYPASSRLS, and receives only source-approved reads.
GRANT SELECT ON TABLE
  public.meteorological_authorities,
  public.metra_account_states,
  public.metra_role_catalogue,
  public.metra_user_profiles,
  public.permission_grants,
  public.registration_audit_events,
  public.registration_requests,
  public.station_assignments,
  public.station_catalogue,
  public.station_coordinates
TO metra_api_runtime;

-- Sequence USAGE is present for Supabase client roles on the six public sequences.
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- Preserve the source's explicit function ACLs.
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
REVOKE EXECUTE ON FUNCTION public.reject_metra_observation_audit_mutation() FROM service_role;

GRANT EXECUTE ON FUNCTION
  public.reject_metra_equipment_fault_audit_mutation(),
  public.reject_metra_support_incident_audit_mutation()
TO anon, authenticated;

GRANT EXECUTE ON FUNCTION private.decide_metra_registration(
  uuid, text, uuid, text, text, timestamp with time zone
) TO metra_api_runtime;

GRANT EXECUTE ON FUNCTION private.submit_metra_registration(
  uuid, text, text, text, text, text, uuid, text, timestamp with time zone, text
) TO metra_api_runtime;
