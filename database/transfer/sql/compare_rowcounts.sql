-- Exact row counts for application tables in public/private. This performs COUNT(*) on each table.
-- Managed Supabase schemas are excluded.
SELECT format(
  'SELECT %L::text AS schema_name, %L::text AS table_name, count(*)::bigint AS exact_rows FROM %I.%I;',
  schemaname,
  tablename,
  schemaname,
  tablename
)
FROM pg_tables
WHERE schemaname IN ('public','private')
ORDER BY schemaname, tablename
\gexec
