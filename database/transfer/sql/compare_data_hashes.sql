-- Exact content fingerprints for every application table except the
-- deliberately excluded non-demo observation history table.
-- Run with psql: the generated SELECT statements are executed by \gexec.
SELECT format(
  'SELECT %L::text AS schema_name, %L::text AS table_name, count(*)::bigint AS exact_rows, encode(extensions.digest(COALESCE(string_agg(to_jsonb(t)::text, chr(10) ORDER BY to_jsonb(t)::text), %L), %L), %L) AS content_sha256 FROM %I.%I AS t;',
  schemaname,
  tablename,
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
