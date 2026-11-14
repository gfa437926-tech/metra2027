-- Deterministic structural fingerprint for application-owned public/private objects.
-- Includes columns, definitions, constraints, triggers, RLS flags, and policy expressions.
SELECT object_type, object_schema, object_name, object_detail
FROM (
  SELECT
    CASE c.relkind
      WHEN 'r' THEN 'table'
      WHEN 'p' THEN 'partitioned_table'
      WHEN 'v' THEN 'view'
      WHEN 'm' THEN 'materialized_view'
      WHEN 'S' THEN 'sequence'
      WHEN 'f' THEN 'foreign_table'
      WHEN 'i' THEN 'index'
      WHEN 'I' THEN 'partitioned_index'
    END AS object_type,
    n.nspname AS object_schema,
    c.relname AS object_name,
    CASE
      WHEN c.relkind IN ('i','I') THEN md5(pg_get_indexdef(c.oid))
      WHEN c.relkind IN ('v','m') THEN md5(pg_get_viewdef(c.oid,true))
      WHEN c.relkind='S' THEN concat_ws('|',s.seqtypid::regtype::text,s.seqstart,s.seqincrement,s.seqmax,s.seqmin,s.seqcache,s.seqcycle)
      ELSE concat_ws('|',c.relrowsecurity::text,c.relforcerowsecurity::text)
    END AS object_detail
  FROM pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace
  LEFT JOIN pg_sequence s ON s.seqrelid=c.oid
  WHERE n.nspname IN ('public','private')
    AND c.relkind IN ('r','p','v','m','S','f','i','I')

  UNION ALL

  SELECT
    'column',
    n.nspname,
    c.relname || '.' || a.attname,
    concat_ws('|',
      format_type(a.atttypid,a.atttypmod),
      a.attnotnull::text,
      COALESCE(pg_get_expr(ad.adbin,ad.adrelid),''),
      a.attidentity::text,
      a.attgenerated::text,
      COALESCE(coll.collname,'')
    )
  FROM pg_attribute a
  JOIN pg_class c ON c.oid=a.attrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  LEFT JOIN pg_attrdef ad ON ad.adrelid=a.attrelid AND ad.adnum=a.attnum
  LEFT JOIN pg_collation coll ON coll.oid=a.attcollation AND a.attcollation<>0
  WHERE n.nspname IN ('public','private')
    AND c.relkind IN ('r','p','v','m','f')
    AND a.attnum>0
    AND NOT a.attisdropped

  UNION ALL

  SELECT
    CASE p.prokind WHEN 'p' THEN 'procedure' ELSE 'function' END,
    n.nspname,
    p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
    md5(pg_get_functiondef(p.oid))
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname IN ('public','private')
    AND p.prokind IN ('f','p')

  UNION ALL

  SELECT
    CASE t.typtype WHEN 'c' THEN 'composite_type' WHEN 'e' THEN 'enum' WHEN 'd' THEN 'domain' ELSE 'range' END,
    n.nspname,
    t.typname,
    CASE
      WHEN t.typtype='e' THEN (
        SELECT string_agg(e.enumlabel,',' ORDER BY e.enumsortorder)
        FROM pg_enum e WHERE e.enumtypid=t.oid
      )
      WHEN t.typtype='d' THEN concat_ws('|',format_type(t.typbasetype,t.typtypmod),t.typnotnull::text,COALESCE(pg_get_expr(t.typdefaultbin,0),''))
      WHEN t.typtype='r' THEN (
        SELECT rngsubtype::regtype::text FROM pg_range WHERE rngtypid=t.oid
      )
      ELSE (
        SELECT string_agg(a.attname || ':' || format_type(a.atttypid,a.atttypmod) || ':' || a.attnotnull::text,',' ORDER BY a.attnum)
        FROM pg_attribute a
        WHERE a.attrelid=t.typrelid AND a.attnum>0 AND NOT a.attisdropped
      )
    END
  FROM pg_type t
  JOIN pg_namespace n ON n.oid=t.typnamespace
  WHERE n.nspname IN ('public','private')
    AND t.typtype IN ('c','e','d','r')
    AND NOT EXISTS (
      SELECT 1 FROM pg_class c
      WHERE c.oid=t.typrelid AND c.relkind IN ('r','p','v','m','f')
    )

  UNION ALL

  SELECT
    'constraint',
    n.nspname,
    c.relname || '.' || con.conname,
    md5(pg_get_constraintdef(con.oid,true))
  FROM pg_constraint con
  JOIN pg_class c ON c.oid=con.conrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname IN ('public','private')

  UNION ALL

  SELECT
    'domain_constraint',
    n.nspname,
    t.typname || '.' || con.conname,
    md5(pg_get_constraintdef(con.oid,true))
  FROM pg_constraint con
  JOIN pg_type t ON t.oid=con.contypid
  JOIN pg_namespace n ON n.oid=t.typnamespace
  WHERE n.nspname IN ('public','private')
    AND con.contypid<>0

  UNION ALL

  SELECT
    'trigger',
    n.nspname,
    c.relname || '.' || trg.tgname,
    md5(pg_get_triggerdef(trg.oid,true))
  FROM pg_trigger trg
  JOIN pg_class c ON c.oid=trg.tgrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname IN ('public','private')
    AND NOT trg.tgisinternal

  UNION ALL

  SELECT
    'policy',
    schemaname,
    tablename || '.' || policyname,
    md5(concat_ws('|',permissive,array_to_string(roles,','),cmd,COALESCE(qual,''),COALESCE(with_check,'')))
  FROM pg_policies
  WHERE schemaname IN ('public','private')
) inventory
ORDER BY object_schema,object_type,object_name,object_detail;
