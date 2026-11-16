-- Compare Auth FK cardinality while allowing target-generated UUID values to differ.
-- Every non-null source reference must be remapped; the import script enforces the mapping.
SELECT format(
  'SELECT %L::text AS schema_name, %L::text AS table_name, %L::text AS column_name, count(*)::bigint AS rows, count(%I)::bigint AS non_null_values, count(DISTINCT %I)::bigint AS distinct_values FROM %I.%I;',
  n.nspname,
  c.relname,
  a.attname,
  a.attname,
  a.attname,
  n.nspname,
  c.relname
)
FROM pg_constraint con
JOIN pg_class c ON c.oid=con.conrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
CROSS JOIN LATERAL unnest(con.conkey) AS fk(attnum)
JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum=fk.attnum
WHERE con.contype='f'
  AND con.confrelid='auth.users'::regclass
  AND n.nspname IN ('public','private')
ORDER BY n.nspname,c.relname,a.attname
\gexec
