-- Deterministic inventory of application-owned public objects.
-- Managed Supabase schemas and private are intentionally excluded from this public-only transfer.
-- This is not a byte-for-byte schema-definition diff.
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
    ''::text AS object_detail
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f', 'i', 'I')

  UNION ALL

  SELECT
    CASE p.prokind WHEN 'p' THEN 'procedure' ELSE 'function' END,
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid)
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'

  UNION ALL

  SELECT
    CASE t.typtype WHEN 'c' THEN 'composite_type' WHEN 'e' THEN 'enum' WHEN 'd' THEN 'domain' ELSE 'range' END,
    n.nspname,
    t.typname::text,
    ''
  FROM pg_type t
  JOIN pg_namespace n ON n.oid = t.typnamespace
  WHERE n.nspname = 'public'
    AND t.typtype IN ('c', 'e', 'd', 'r')
    AND NOT EXISTS (
      SELECT 1 FROM pg_class c
      WHERE c.oid = t.typrelid AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
    )

  UNION ALL

  SELECT
    'constraint',
    n.nspname,
    c.relname || '.' || con.conname,
    con.contype::text
  FROM pg_constraint con
  JOIN pg_class c ON c.oid = con.conrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'

  UNION ALL

  SELECT
    'trigger',
    n.nspname,
    c.relname || '.' || trg.tgname,
    ''
  FROM pg_trigger trg
  JOIN pg_class c ON c.oid = trg.tgrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND NOT trg.tgisinternal

  UNION ALL

  SELECT
    'policy',
    schemaname,
    tablename || '.' || policyname,
    cmd
  FROM pg_policies
  WHERE schemaname = 'public'
) inventory
ORDER BY object_schema, object_type, object_name, object_detail;
