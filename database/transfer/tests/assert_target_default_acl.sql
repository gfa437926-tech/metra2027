DO $$
DECLARE
  unsafe_public_defaults integer;
  unsafe_private_defaults integer;
  service_table_privileges integer;
  service_sequence_privileges integer;
  service_function_privileges integer;
  runtime_private_function_privileges integer;
BEGIN
  SELECT count(*)
  INTO unsafe_public_defaults
  FROM pg_default_acl d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) a
  WHERE d.defaclrole='postgres'::regrole
    AND d.defaclnamespace='public'::regnamespace
    AND a.grantee IN (0, 'anon'::regrole::oid, 'authenticated'::regrole::oid);

  IF unsafe_public_defaults <> 0 THEN
    RAISE EXCEPTION 'Unsafe public default ACL: PUBLIC/anon/authenticated receive implicit privileges';
  END IF;

  SELECT count(*)
  INTO unsafe_private_defaults
  FROM pg_default_acl d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) a
  WHERE d.defaclrole='postgres'::regrole
    AND d.defaclnamespace='private'::regnamespace
    AND a.grantee IN (0, 'anon'::regrole::oid, 'authenticated'::regrole::oid, 'service_role'::regrole::oid);

  IF unsafe_private_defaults <> 0 THEN
    RAISE EXCEPTION 'Unsafe private default ACL: public/client/service roles receive implicit privileges';
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
    RAISE EXCEPTION 'service_role must retain all 7 public default table privileges; found %', service_table_privileges;
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
    RAISE EXCEPTION 'service_role must retain all 3 public default sequence privileges; found %', service_sequence_privileges;
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
    RAISE EXCEPTION 'service_role must retain public default function EXECUTE; found %', service_function_privileges;
  END IF;

  SELECT count(DISTINCT a.privilege_type)
  INTO runtime_private_function_privileges
  FROM pg_default_acl d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) a
  WHERE d.defaclrole='postgres'::regrole
    AND d.defaclnamespace='private'::regnamespace
    AND d.defaclobjtype='f'
    AND a.grantee='metra_api_runtime'::regrole::oid;

  IF runtime_private_function_privileges <> 1 THEN
    RAISE EXCEPTION 'metra_api_runtime must retain private default function EXECUTE; found %', runtime_private_function_privileges;
  END IF;
END
$$;
