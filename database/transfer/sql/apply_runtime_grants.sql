-- Reapply the source-approved grants excluded by pg_dump --no-privileges.
-- Exact grant inventory observed on the approved experimental source.
GRANT USAGE ON SCHEMA public, private TO metra_api_runtime;

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

GRANT EXECUTE ON FUNCTION private.decide_metra_registration(
  uuid, text, uuid, text, text, timestamp with time zone
) TO metra_api_runtime;

GRANT EXECUTE ON FUNCTION private.submit_metra_registration(
  uuid, text, text, text, text, text, uuid, text, timestamp with time zone, text
) TO metra_api_runtime;
