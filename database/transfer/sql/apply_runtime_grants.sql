-- Reapply ACLs excluded by pg_dump --no-privileges.
-- The exact source ACL inventory is recorded in 06_runtime_role_inventory.txt.

-- Schema access: client roles have public USAGE only; private is restricted.
REVOKE CREATE ON SCHEMA public FROM PUBLIC, anon, authenticated, service_role, metra_api_runtime;
REVOKE CREATE ON SCHEMA private FROM PUBLIC, anon, authenticated, service_role, metra_api_runtime;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated, service_role, metra_api_runtime;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role, metra_api_runtime;
GRANT USAGE ON SCHEMA private TO metra_api_runtime;

-- Existing table ACLs are narrower than Supabase default ACLs; reset then reapply.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
  FROM PUBLIC, anon, authenticated, service_role, metra_api_runtime;
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

-- Source grants ALL sequence privileges to anon/authenticated/service_role,
-- and none to PUBLIC or metra_api_runtime.
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, metra_api_runtime;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- Reset existing function ACLs because Supabase defaults are broader than
-- several source-specific RPC/trigger ACLs.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public
  FROM PUBLIC, anon, authenticated, service_role, metra_api_runtime;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
REVOKE EXECUTE ON FUNCTION public.reject_metra_observation_audit_mutation()
  FROM PUBLIC, anon, authenticated, service_role, metra_api_runtime;
GRANT EXECUTE ON FUNCTION
  public.reject_metra_equipment_fault_audit_mutation(),
  public.reject_metra_support_incident_audit_mutation()
TO PUBLIC, anon, authenticated;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA private
  FROM PUBLIC, anon, authenticated, service_role, metra_api_runtime;
GRANT EXECUTE ON FUNCTION private.reject_authority_access_audit_mutation()
  TO PUBLIC;
GRANT EXECUTE ON FUNCTION private.decide_metra_registration(
  uuid, text, uuid, text, text, timestamp with time zone
) TO metra_api_runtime;
GRANT EXECUTE ON FUNCTION private.submit_metra_registration(
  uuid, text, text, text, text, text, uuid, text, timestamp with time zone, text
) TO metra_api_runtime;
