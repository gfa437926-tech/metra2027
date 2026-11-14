-- Create an isolated fixture for Supabase managed-role and runtime ACL checks.
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
CREATE TABLE public.authority_access_audit_events(id uuid);
CREATE TABLE public.authority_memberships(id uuid);
CREATE TABLE public.countries(id uuid);
CREATE TABLE public.metra_equipment_fault_audit_events(id uuid);
CREATE TABLE public.metra_equipment_faults(id uuid);
CREATE TABLE public.metra_observation_audit_events(id uuid);
CREATE TABLE public.metra_observation_records(id uuid);
CREATE TABLE public.metra_observations(id uuid);
CREATE TABLE public.metra_role_permissions(id uuid);
CREATE TABLE public.metra_support_incident_audit_events(id uuid);
CREATE TABLE public.metra_support_incidents(id uuid);
CREATE TABLE public.station_access_grants(id uuid);
CREATE TABLE public.station_audit_log(id uuid);

CREATE SEQUENCE public.authority_access_audit_events_id_seq;
CREATE SEQUENCE public.metra_equipment_fault_audit_events_id_seq;
CREATE SEQUENCE public.metra_observation_audit_events_id_seq;
CREATE SEQUENCE public.metra_support_incident_audit_events_id_seq;
CREATE SEQUENCE public.registration_audit_events_id_seq;
CREATE SEQUENCE public.station_audit_log_id_seq;

CREATE FUNCTION private.decide_metra_registration(
  uuid, text, uuid, text, text, timestamp with time zone
) RETURNS TABLE(result_status text, resulting_status text)
LANGUAGE sql AS 'SELECT ''ok''::text, ''approved''::text';

CREATE FUNCTION private.submit_metra_registration(
  uuid, text, text, text, text, text, uuid, text, timestamp with time zone, text
) RETURNS TABLE(result_status text, account_id uuid, request_id uuid)
LANGUAGE sql AS 'SELECT ''ok''::text, NULL::uuid, NULL::uuid';

CREATE FUNCTION public.reject_metra_equipment_fault_audit_mutation()
RETURNS trigger LANGUAGE plpgsql AS 'BEGIN RAISE EXCEPTION ''immutable''; END;';

CREATE FUNCTION public.reject_metra_support_incident_audit_mutation()
RETURNS trigger LANGUAGE plpgsql AS 'BEGIN RAISE EXCEPTION ''immutable''; END;';

CREATE FUNCTION public.reject_metra_observation_audit_mutation()
RETURNS trigger LANGUAGE plpgsql AS 'BEGIN RAISE EXCEPTION ''immutable''; END;';

CREATE FUNCTION private.reject_authority_access_audit_mutation()
RETURNS trigger LANGUAGE plpgsql AS 'BEGIN RAISE EXCEPTION ''immutable''; END;';

CREATE FUNCTION public.get_authority_catalogue()
RETURNS text LANGUAGE sql AS 'SELECT ''fixture''::text';
