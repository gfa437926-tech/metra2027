-- Sequence definitions and current values must match after pg_dump setval restoration.
SELECT schemaname || '|' || sequencename || '|' ||
       start_value::text || '|' || increment_by::text || '|' ||
       max_value::text || '|' || min_value::text || '|' ||
       cache_size::text || '|' || cycle::text || '|' ||
       COALESCE(last_value::text, 'NULL')
FROM pg_sequences
WHERE schemaname IN ('public','private')
ORDER BY schemaname, sequencename;
