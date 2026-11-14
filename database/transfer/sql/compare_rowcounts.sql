-- Approximate live row counts (analyze may be needed for accuracy)
SELECT
  n.nspname AS schema,
  c.relname AS table_name,
  c.reltuples::bigint AS approx_rows
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
ORDER BY 1, 2;
