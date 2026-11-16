-- Required extension inventory; target may contain additional extensions.
SELECT e.extname || '|' || e.extversion || '|' || n.nspname
FROM pg_extension e
JOIN pg_namespace n ON n.oid=e.extnamespace
ORDER BY e.extname;
