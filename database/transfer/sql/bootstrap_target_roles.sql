-- Create the source-compatible, non-login runtime role before importing
-- public policies/private functions that reference it. Target-only bootstrap.
DO $$
DECLARE
  role_row record;
BEGIN
  IF (
    SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p','v','m','S','f')
  ) + (
    SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname IN ('public','private')
  ) + (
    SELECT count(*) FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname IN ('public','private') AND t.typtype IN ('c','e','d','r')
  ) > 0 THEN
    RAISE EXCEPTION 'Target public/private application schemas are not empty; refusing bootstrap';
  END IF;

  SELECT rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin,
         rolreplication, rolbypassrls
  INTO role_row
  FROM pg_roles
  WHERE rolname = 'metra_api_runtime';

  IF NOT FOUND THEN
    EXECUTE 'CREATE ROLE metra_api_runtime NOLOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS';
  ELSIF role_row.rolsuper
     OR NOT role_row.rolinherit
     OR role_row.rolcreaterole
     OR role_row.rolcreatedb
     OR role_row.rolcanlogin
     OR role_row.rolreplication
     OR role_row.rolbypassrls THEN
    RAISE EXCEPTION 'Existing metra_api_runtime role has unexpected privileged attributes; refusing bootstrap';
  END IF;
END
$$;

CREATE SCHEMA IF NOT EXISTS private;
GRANT USAGE ON SCHEMA public, private TO metra_api_runtime;
GRANT metra_api_runtime TO postgres WITH ADMIN OPTION;
