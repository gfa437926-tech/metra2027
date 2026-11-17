-- C2.4 isolated tests against the PROPOSED function body (applied only to this DB).
\set ON_ERROR_STOP on

DO $$
DECLARE
  u uuid := '11111111-1111-1111-1111-111111111111';
  st_a uuid := 'aaaaaaaa-0001-0001-0001-000000000001';
  st_b uuid := 'aaaaaaaa-0002-0002-0002-000000000002';
  ok boolean;
  g uuid;
BEGIN
  -- Positive: station A archive grant
  ok := public.metra_user_has_station_permission(u, st_a, 'observation.archive.read');
  IF ok IS NOT TRUE THEN RAISE EXCEPTION 'FAIL allow A'; END IF;
  RAISE NOTICE 'PASS: archive A allowed with station grant';

  -- Negative: station B same authority
  ok := public.metra_user_has_station_permission(u, st_b, 'observation.archive.read');
  IF ok IS TRUE THEN RAISE EXCEPTION 'FAIL deny B'; END IF;
  RAISE NOTICE 'PASS: archive B denied';

  -- Authority-only grant style: insert grant with station_id null for create perm if allowed by CHECK
  -- archive null station rejected by CHECK; use non-archive permission for authority-only path
  -- For archive, null station cannot be inserted when archive CHECK exists.

  -- Revoke A
  SELECT id INTO g FROM permission_grants
   WHERE user_id = u AND station_id = st_a AND permission_code = 'observation.archive.read'
     AND revoked_at IS NULL LIMIT 1;
  UPDATE permission_grants SET revoked_at = statement_timestamp() WHERE id = g;
  ok := public.metra_user_has_station_permission(u, st_a, 'observation.archive.read');
  IF ok IS TRUE THEN RAISE EXCEPTION 'FAIL after revoke'; END IF;
  RAISE NOTICE 'PASS: archive denied after revoke';

  -- Restore grant for later
  UPDATE permission_grants SET revoked_at = NULL WHERE id = g;
  INSERT INTO permission_grant_audit(grant_id, action, permission_code, station_id, note)
  VALUES (g, 'granted', 'observation.archive.read', st_a, 'restore after revoke test')
  ON CONFLICT DO NOTHING;

  RAISE NOTICE 'ALL R4 PROPOSED FUNCTION TESTS PASSED';
END $$;
