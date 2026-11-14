-- Create an isolated fixture for runtime role grant verification.
CREATE TABLE public.meteorological_authorities(id uuid);
CREATE TABLE public.metra_account_states(id uuid);
CREATE TABLE public.metra_role_catalogue(id uuid);
CREATE TABLE public.metra_user_profiles(id uuid);
CREATE TABLE public.permission_grants(id uuid);
CREATE TABLE public.registration_audit_events(id uuid);
CREATE TABLE public.registration_requests(id uuid);
CREATE TABLE public.station_assignments(id uuid);
CREATE TABLE public.station_catalogue(id uuid);
CREATE TABLE public.station_coordinates(id uuid);

CREATE FUNCTION private.decide_metra_registration(
  uuid, text, uuid, text, text, timestamp with time zone
) RETURNS TABLE(result_status text, resulting_status text)
LANGUAGE sql AS $$ SELECT 'ok'::text, 'approved'::text $$;

CREATE FUNCTION private.submit_metra_registration(
  uuid, text, text, text, text, text, uuid, text, timestamp with time zone, text
) RETURNS TABLE(result_status text, account_id uuid, request_id uuid)
LANGUAGE sql AS $$ SELECT 'ok'::text, NULL::uuid, NULL::uuid $$;
