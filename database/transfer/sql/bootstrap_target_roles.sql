-- Target-only bootstrap. Recreate the least-privilege custom runtime role
-- and Supabase public-schema default ACLs observed on the approved source.
DO $$
DECLARE
  role_row record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon')
     OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated')
     OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role')
     OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='postgres') THEN
    RAISE EXCEPTION 'Required Supabase managed roles are missing; refusing target bootstrap';
  END IF;

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
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA public, private TO metra_api_runtime;
GRANT metra_api_runtime TO postgres WITH ADMIN OPTION;

-- Recreate the approved source's public-schema defaults for future objects.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT ALL PRIVILEGES ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT ALL PRIVILEGES ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;
