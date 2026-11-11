-- PROPOSAL ONLY — Stage B
-- DO NOT APPLY TO HOSTED SUPABASE without explicit human approval.
-- Test only in isolated PostgreSQL.
--
-- Policy (approved 2026-11-11):
--   observation.archive.read is an explicit per-station permission grant.
--   Never inferred from role or authority membership.
--   Grant for station A does not authorize station B (even same authority).
--   Grant create/revoke/update must be audited.

-- Example permission catalogue row (idempotent insert pattern used elsewhere):
-- INSERT INTO public.metra_permission_codes (code, description)
-- VALUES ('observation.archive.read', 'Read station-scoped observation archive')
-- ON CONFLICT (code) DO NOTHING;
--
-- Grants must bind (user_id, station_id, permission_code, authority_id, validity window).
-- RPCs that evaluate archive read must require:
--   active account + approved station assignment for THAT station
--   + unrevoked time-valid individual grant of observation.archive.read for THAT station.
--
-- Negative tests required before hosted apply:
--   1) user with archive grant on A cannot read B
--   2) user with observation.review on A cannot read archive without archive grant
--   3) authority membership alone cannot read archive
--   4) audit table rejects UPDATE/DELETE on grant history

-- This file intentionally contains no executable DDL that mutates production.
SELECT 'observation_archive_read_permission_proposal_not_applied' AS status;
