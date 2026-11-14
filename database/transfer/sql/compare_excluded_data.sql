-- The observation history is intentionally not transferred.
-- This target-side acceptance query must return zero.
SELECT count(*)::bigint
FROM public.metra_observation_records;
