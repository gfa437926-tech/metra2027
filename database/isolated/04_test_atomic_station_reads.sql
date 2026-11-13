\set ON_ERROR_STOP on
DO $$
DECLARE
 observer uuid := '11111111-1111-1111-1111-111111111111';
 reviewer uuid := '22222222-2222-2222-2222-222222222222';
 station_a uuid := 'aaaaaaaa-0001-0001-0001-000000000001';
 station_b uuid := 'aaaaaaaa-0002-0002-0002-000000000002';
 n integer;
 v_archive jsonb;
 v_second jsonb;
 v_cursor text;
 v_item_id uuid;
 v_grant_id uuid;
BEGIN
 IF private.metra_lock_authorized_station_read(reviewer,station_a,'users.station.view') IS NOT TRUE THEN
  RAISE EXCEPTION 'authorized reviewer denied on assigned station'; END IF;
 IF private.metra_lock_authorized_station_read(reviewer,station_b,'users.station.view') IS TRUE THEN
  RAISE EXCEPTION 'reviewer unexpectedly authorized for unassigned station'; END IF;
 IF private.metra_lock_authorized_station_read(observer,station_a,'users.station.view') IS TRUE THEN
  RAISE EXCEPTION 'observer unexpectedly inherited station directory permission'; END IF;
 IF private.metra_lock_authorized_station_read(NULL,station_a,'users.station.view') IS TRUE THEN
  RAISE EXCEPTION 'null actor unexpectedly authorized'; END IF;
 SELECT count(*) INTO n FROM public.get_station_user_directory_atomic(reviewer,station_a,100);
 IF n <> 2 THEN RAISE EXCEPTION 'expected 2 directory rows, got %',n; END IF;
 SELECT count(*) INTO n FROM public.get_station_audit_log_atomic(reviewer,station_a,100);
 IF n <> 1 THEN RAISE EXCEPTION 'expected 1 audit row, got %',n; END IF;
 SELECT count(*) INTO n FROM public.get_station_observation_review_queue_atomic(reviewer,station_a,100);
 IF n <> 1 THEN RAISE EXCEPTION 'expected 1 queue row, got %',n; END IF;
 BEGIN
  PERFORM * FROM public.get_station_user_directory_atomic(observer,station_a,100);
  RAISE EXCEPTION 'unauthorized directory call unexpectedly succeeded';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

 v_archive := public.get_station_observation_archive_atomic(
   observer,station_a,NULL,NULL,NULL,1,NULL);
 IF jsonb_array_length(v_archive->'items') <> 1 THEN
  RAISE EXCEPTION 'archive first page must contain one item'; END IF;
 IF v_archive->>'hasMore' <> 'true' OR v_archive->>'nextCursor' IS NULL THEN
  RAISE EXCEPTION 'archive first page must return a continuation cursor'; END IF;
 v_cursor := v_archive->>'nextCursor';
 v_item_id := (v_archive->'items'->0->>'id')::uuid;
 IF (v_archive->'items'->0->'payload') ? 'raw_data'
    OR (v_archive->'items'->0->'payload') ? 'station_name'
    OR (v_archive->'items'->0->'payload') ? 'user_station' THEN
  RAISE EXCEPTION 'archive payload exposed a private/workflow field'; END IF;
 v_second := public.get_station_observation_archive_atomic(
   observer,station_a,NULL,NULL,NULL,1,v_cursor);
 IF jsonb_array_length(v_second->'items') <> 1 OR v_second->>'hasMore' <> 'false' THEN
  RAISE EXCEPTION 'archive cursor did not return the remaining station-A record'; END IF;
 IF public.get_station_observation_archive_item_atomic(observer,station_a,v_item_id) IS NULL THEN
  RAISE EXCEPTION 'authorized archive detail was not returned'; END IF;
 IF public.get_station_observation_archive_item_atomic(
   observer,station_a,'eeeeeeee-0002-0002-0002-000000000003') IS NOT NULL THEN
  RAISE EXCEPTION 'cross-station archive detail leaked'; END IF;
 SELECT id INTO v_grant_id FROM public.permission_grants
  WHERE user_id=observer AND authority_id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    AND permission_code='observation.archive.read';
 UPDATE public.permission_grants SET revoked_at=now() WHERE id=v_grant_id;
 BEGIN
  PERFORM public.get_station_observation_archive_atomic(observer,station_a,NULL,NULL,NULL,10,NULL);
  RAISE EXCEPTION 'revoked archive grant unexpectedly read records';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 UPDATE public.permission_grants SET revoked_at=NULL WHERE id=v_grant_id;

 RAISE NOTICE 'PASS: actor-bound directory, audit, review queue and station archive; pagination, payload redaction and grant revocation';
END $$;
