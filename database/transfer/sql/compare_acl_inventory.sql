-- Stable, deterministic ACL inventory for the application-owned schemas.
-- This query is read-only and excludes managed Auth/Storage schemas.
SELECT item::text
FROM (
  SELECT '01_role'::text AS sort_key,
         jsonb_build_object('kind','role','rolname',rolname,'rolsuper',rolsuper,'rolinherit',rolinherit,
           'rolcreaterole',rolcreaterole,'rolcreatedb',rolcreatedb,'rolcanlogin',rolcanlogin,
           'rolreplication',rolreplication,'rolbypassrls',rolbypassrls) AS item
  FROM pg_roles
  WHERE rolname IN ('anon','authenticated','service_role','metra_api_runtime','postgres','pg_database_owner')
  UNION ALL
  SELECT '02_schema',
         jsonb_build_object('kind','schema_privilege','role',r.rolname,'schema',n.nspname,
           'usage',has_schema_privilege(r.rolname,n.oid,'USAGE'),
           'create',has_schema_privilege(r.rolname,n.oid,'CREATE'))
  FROM pg_roles r CROSS JOIN pg_namespace n
  WHERE n.nspname IN ('public','private')
    AND r.rolname IN ('anon','authenticated','service_role','metra_api_runtime','postgres','pg_database_owner')
  UNION ALL
  SELECT '03_table',
         jsonb_build_object('kind','table_privilege','grantee',grantee,'schema',table_schema,
           'table',table_name,'privilege',privilege_type,'grantable',is_grantable)
  FROM information_schema.role_table_grants
  WHERE table_schema IN ('public','private')
    AND grantee IN ('anon','authenticated','service_role','metra_api_runtime')
  UNION ALL
  SELECT '04_sequence',
         jsonb_build_object('kind','sequence_privilege','grantee',r.rolname,'schema',n.nspname,
           'sequence',c.relname,
           'usage',has_sequence_privilege(r.rolname,c.oid,'USAGE'),
           'select',has_sequence_privilege(r.rolname,c.oid,'SELECT'),
           'update',has_sequence_privilege(r.rolname,c.oid,'UPDATE'))
  FROM pg_roles r CROSS JOIN pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE c.relkind='S' AND n.nspname IN ('public','private')
    AND r.rolname IN ('anon','authenticated','service_role','metra_api_runtime')
  UNION ALL
  SELECT '05_routine',
         jsonb_build_object('kind','routine_privilege','grantee',r.grantee,'schema',r.routine_schema,
           'routine',r.routine_name,'identity_arguments',pg_get_function_identity_arguments(p.oid),
           'privilege',r.privilege_type,'grantable',r.is_grantable)
  FROM information_schema.role_routine_grants r
  JOIN pg_proc p ON p.proname=r.routine_name
  JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname=r.routine_schema
  WHERE r.specific_name=p.proname || '_' || p.oid::text
    AND r.routine_schema IN ('public','private')
    AND r.grantee IN ('anon','authenticated','service_role','metra_api_runtime')
  UNION ALL
  SELECT '06_public_acl',
         jsonb_build_object('kind','public_acl','schema',n.nspname,'object_type','function',
           'object_name',p.proname,'identity_arguments',pg_get_function_identity_arguments(p.oid),
           'privilege',a.privilege_type,'grantable',a.is_grantable)
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f',p.proowner))) a
  WHERE n.nspname IN ('public','private') AND a.grantee=0
  UNION ALL
  SELECT '06_public_acl',
         jsonb_build_object('kind','public_acl','schema',n.nspname,'object_type','relation',
           'object_name',c.relname,'privilege',a.privilege_type,'grantable',a.is_grantable)
  FROM pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace
  CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('r',c.relowner))) a
  WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p','v','m','f') AND a.grantee=0
  UNION ALL
  SELECT '06_public_acl',
         jsonb_build_object('kind','public_acl','schema',n.nspname,'object_type','sequence',
           'object_name',c.relname,'privilege',a.privilege_type,'grantable',a.is_grantable)
  FROM pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace
  CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('S',c.relowner))) a
  WHERE n.nspname IN ('public','private') AND c.relkind='S' AND a.grantee=0
  UNION ALL
  SELECT '06_public_acl',
         jsonb_build_object('kind','public_acl','schema',n.nspname,'object_type','schema',
           'object_name',n.nspname,'privilege',a.privilege_type,'grantable',a.is_grantable)
  FROM pg_namespace n
  CROSS JOIN LATERAL aclexplode(COALESCE(n.nspacl, acldefault('n',n.nspowner))) a
  WHERE n.nspname IN ('public','private') AND a.grantee=0
  UNION ALL
  SELECT '07_default_acl',
         jsonb_build_object('kind','default_acl','owner',pg_get_userbyid(d.defaclrole),
           'schema',d.defaclnamespace::regnamespace::text,'object_type',d.defaclobjtype,
           'grantee',CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END,
           'privilege',a.privilege_type,'grantable',a.is_grantable)
  FROM pg_default_acl d
  CROSS JOIN LATERAL aclexplode(d.defaclacl) a
  WHERE d.defaclrole='postgres'::regrole
    AND d.defaclnamespace='public'::regnamespace
  UNION ALL
  SELECT '08_membership',
         jsonb_build_object('kind','membership','granted_role',granted.rolname,
           'member_role',member.rolname,'admin_option',m.admin_option)
  FROM pg_auth_members m
  JOIN pg_roles granted ON granted.oid=m.roleid
  JOIN pg_roles member ON member.oid=m.member
  WHERE granted.rolname='metra_api_runtime' OR member.rolname='metra_api_runtime'
) inventory(sort_key,item)
ORDER BY sort_key,item::text;
