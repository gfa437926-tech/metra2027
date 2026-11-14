-- Exact content fingerprints for application tables, excluding only declared
-- auth.users FK columns because target Auth UUIDs are intentionally regenerated.
-- Those excluded columns are independently compared by compare_auth_fk_counts.sql.
SELECT format(
  'SELECT %L::text AS schema_name, %L::text AS table_name, count(*)::bigint AS exact_rows, encode(extensions.digest(COALESCE(string_agg((to_jsonb(t) - %L::text[])::text, chr(10) ORDER BY (to_jsonb(t) - %L::text[])::text), %L), %L), %L) AS content_sha256 FROM %I.%I AS t;',
  schemaname,
  tablename,
  COALESCE((
    SELECT array_agg(a.attname)::text
    FROM pg_constraint con
    CROSS JOIN LATERAL unnest(con.conkey) AS fk(attnum)
    JOIN pg_attribute a ON a.attrelid=con.conrelid AND a.attnum=fk.attnum
    WHERE con.contype='f'
      AND con.confrelid='auth.users'::regclass
      AND con.conrelid=format('%I.%I',schemaname,tablename)::regclass
  ), '{}'),
  COALESCE((
    SELECT array_agg(a.attname)::text
    FROM pg_constraint con
    CROSS JOIN LATERAL unnest(con.conkey) AS fk(attnum)
    JOIN pg_attribute a ON a.attrelid=con.conrelid AND a.attnum=fk.attnum
    WHERE con.contype='f'
      AND con.confrelid='auth.users'::regclass
      AND con.conrelid=format('%I.%I',schemaname,tablename)::regclass
  ), '{}'),
  '',
  'sha256',
  'hex',
  schemaname,
  tablename
)
FROM pg_tables
WHERE schemaname IN ('public','private')
  AND NOT (schemaname='public' AND tablename='metra_observation_records')
ORDER BY schemaname, tablename
\gexec
