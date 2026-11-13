-- Stage C: live archive isolation assertions. Exit non-zero on failure.
\set ON_ERROR_STOP on

DO $$
DECLARE
  u_observer uuid := '11111111-1111-1111-1111-111111111111';
  u_reviewer uuid := '22222222-2222-2222-2222-222222222222';
  st_a uuid := 'aaaaaaaa-0001-0001-0001-000000000001';
  st_b uuid := 'aaaaaaaa-0002-0002-0002-000000000002';
  ok boolean;
  v_grant_id uuid;
BEGIN
  ok := public.metra_user_has_station_archive_permission(u_observer, st_a, 'observation.archive.read');
  IF ok IS NOT TRUE THEN
    RAISE EXCEPTION 'FAIL: observer should read archive A';
  END IF;
  RAISE NOTICE 'PASS: observer archive A allowed';

  ok := public.metra_user_has_station_archive_permission(u_observer, st_b, 'observation.archive.read');
  IF ok IS TRUE THEN
    RAISE EXCEPTION 'FAIL: observer must NOT read archive B without grant';
  END IF;
  RAISE NOTICE 'PASS: observer archive B denied (same authority)';

  ok := public.metra_user_has_station_archive_permission(u_reviewer, st_a, 'observation.archive.read');
  IF ok IS TRUE THEN
    RAISE EXCEPTION 'FAIL: role/review alone must not grant archive';
  END IF;
  RAISE NOTICE 'PASS: role-only archive denied';

  SELECT id INTO v_grant_id FROM public.permission_grants
   WHERE user_id = u_observer AND station_id = st_a AND permission_code = 'observation.archive.read'
   LIMIT 1;
  UPDATE public.permission_grants SET revoked_at = now() WHERE id = v_grant_id;
  INSERT INTO public.permission_grant_audit (grant_id, action, actor_user_id, station_id, permission_code, note)
  VALUES (v_grant_id, 'revoked', u_reviewer, st_a, 'observation.archive.read', 'isolated revoke');

  ok := public.metra_user_has_station_archive_permission(u_observer, st_a, 'observation.archive.read');
  IF ok IS TRUE THEN
    RAISE EXCEPTION 'FAIL: revoked grant must deny archive A';
  END IF;
  RAISE NOTICE 'PASS: revoked grant denies archive A';

  UPDATE public.permission_grants SET revoked_at = NULL WHERE id = v_grant_id;

  UPDATE public.station_assignments
     SET valid_to = now() - interval '1 hour'
   WHERE user_id = u_observer AND station_id = st_a;
  ok := public.metra_user_has_station_archive_permission(u_observer, st_a, 'observation.archive.read');
  IF ok IS TRUE THEN
    RAISE EXCEPTION 'FAIL: expired station assignment must deny archive';
  END IF;
  RAISE NOTICE 'PASS: expired assignment denies archive';

  UPDATE public.station_assignments
     SET valid_to = NULL
   WHERE user_id = u_observer AND station_id = st_a;

  BEGIN
    UPDATE public.permission_grant_audit AS a SET note = 'tamper' WHERE a.grant_id = v_grant_id;
    RAISE EXCEPTION 'FAIL: audit update should have been blocked';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: audit update blocked';
  END;

  BEGIN
    DELETE FROM public.permission_grant_audit AS a WHERE a.grant_id = v_grant_id;
    RAISE EXCEPTION 'FAIL: audit delete should have been blocked';
  EXCEPTION WHEN SQLSTATE '55000' THEN
    RAISE NOTICE 'PASS: audit delete blocked';
  END;

  RAISE NOTICE 'ALL ARCHIVE ISOLATION TESTS PASSED';
END $$;
