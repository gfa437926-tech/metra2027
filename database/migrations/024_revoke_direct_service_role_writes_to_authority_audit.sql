REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.authority_access_audit_events FROM service_role;
GRANT SELECT ON public.authority_access_audit_events TO service_role;
