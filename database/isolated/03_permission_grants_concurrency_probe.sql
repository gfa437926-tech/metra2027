-- Path N / isolated concurrency probe for permission_grants.
-- Observational only: documents current schema behavior under parallel writes.
-- Does not alter production constraints.

\set ON_ERROR_STOP on

-- Expect: schema may allow multiple concurrent approved grants for same
-- (user, station, permission) unless exclusion/unique constraint exists.
SELECT count(*) AS constraints_on_grants
FROM pg_constraint
WHERE conrelid = 'public.permission_grants'::regclass;

SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.permission_grants'::regclass
  AND contype IN ('u', 'x');

-- Note: absence of UNIQUE/EXCLUDE on (user_id, station_id, permission_code)
-- for approved rows is a residual risk for concurrent grant issuance.
