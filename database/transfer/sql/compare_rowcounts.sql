-- Exact row counts for application tables. This performs COUNT(*) on each table.
-- Run only against the approved experimental source and the explicitly approved target.
SELECT format(
  'SELECT %L::text AS schema_name, %L::text AS table_name, count(*)::bigint AS exact_rows FROM %I.%I;',
  schemaname,
  tablename,
  schemaname,
  tablename
)
FROM pg_tables
WHERE schemaname IN ('public', 'private')
ORDER BY schemaname, tablename
\gexec
