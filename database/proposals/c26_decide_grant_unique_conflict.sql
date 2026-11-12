-- PROPOSAL ONLY — optional complement to Backend 23505 mapping.
-- If decide_authority_permission_grant hits unique index on approve, return 'conflict'
-- instead of raising uncaught unique_violation (HTTP 500 via PostgREST).
-- DO NOT apply to hosted without explicit approval. Does not replace Backend detector.

-- Sketch (not auto-applied): wrap the UPDATE ... approval_status = 'approved'
-- in:
--   EXCEPTION WHEN unique_violation THEN RETURN 'conflict';
