-- PROPOSAL ONLY — Supabase security advisor search_path findings.
-- Do not apply to hosted Supabase without explicit staging validation and approval.
-- These invoker trigger functions only raise fixed exceptions and require no
-- application schemas or user-controlled search path objects.

CREATE OR REPLACE FUNCTION public.reject_metra_equipment_fault_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
  RAISE EXCEPTION 'metra_equipment_fault_audit_immutable' USING ERRCODE = '42501';
END;
$function$;

CREATE OR REPLACE FUNCTION public.reject_metra_support_incident_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
  RAISE EXCEPTION 'metra_support_incident_audit_immutable' USING ERRCODE = '42501';
END;
$function$;

-- Post-apply verification (read-only):
-- SELECT n.nspname, p.proname, p.proconfig, p.prosecdef
-- FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
-- WHERE n.nspname='public'
--   AND p.proname IN (
--     'reject_metra_equipment_fault_audit_mutation',
--     'reject_metra_support_incident_audit_mutation'
--   );
