DO $$
DECLARE
  unsafe_default_grants integer;
  service_table_privileges integer;
  service_sequence_privileges integer;
  service_function_privileges integer;
BEGIN
  SELECT count(*)
  INTO unsafe_default_grants
  FROM pg_default_acl d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) a
  WHERE d.defaclrole='postgres'::regrole
    AND d.defaclnamespace='public'::regnamespace
    AND a.grantee IN (0, 'anon'::regrole::oid, 'authenticated'::regrole::oid);

  IF unsafe_default_grants <> 0 THEN
    RAISE EXCEPTION 'Unsafe default ACL: PUBLIC/anon/authenticated receive implicit privileges on future public objects';
  END IF;

  SELECT count(DISTINCT a.privilege_type)
  INTO service_table_privileges
  FROM pg_default_acl d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) a
  WHERE d.defaclrole='postgres'::regrole
    AND d.defaclnamespace='public'::regnamespace
    AND d.defaclobjtype='r'
    AND a.grantee='service_role'::regrole::oid;

  IF service_table_privileges <> 7 THEN
    RAISE EXCEPTION 'service_role must retain all 7 default table privileges; found %', service_table_privileges;
  END IF;

  SELECT count(DISTINCT a.privilege_type)
  INTO service_sequence_privileges
  FROM pg_default_acl d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) a
  WHERE d.defaclrole='postgres'::regrole
    AND d.defaclnamespace='public'::regnamespace
    AND d.defaclobjtype='S'
    AND a.grantee='service_role'::regrole::oid;

  IF service_sequence_privileges <> 3 THEN
    RAISE EXCEPTION 'service_role must retain all 3 default sequence privileges; found %', service_sequence_privileges;
  END IF;

  SELECT count(DISTINCT a.privilege_type)
  INTO service_function_privileges
  FROM pg_default_acl d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) a
  WHERE d.defaclrole='postgres'::regrole
    AND d.defaclnamespace='public'::regnamespace
    AND d.defaclobjtype='f'
    AND a.grantee='service_role'::regrole::oid;

  IF service_function_privileges <> 1 THEN
    RAISE EXCEPTION 'service_role must retain default function EXECUTE; found %', service_function_privileges;
  END IF;
END
$$;
