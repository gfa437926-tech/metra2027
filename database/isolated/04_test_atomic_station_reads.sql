\set ON_ERROR_STOP on
DO $$
DECLARE
 observer uuid := '11111111-1111-1111-1111-111111111111';
 reviewer uuid := '22222222-2222-2222-2222-222222222222';
 station_a uuid := 'aaaaaaaa-0001-0001-0001-000000000001';
 station_b uuid := 'aaaaaaaa-0002-0002-0002-000000000002';
 n integer;
BEGIN
 IF public.metra_lock_authorized_station_read(reviewer,station_a,'users.station.view') IS NOT TRUE THEN
  RAISE EXCEPTION 'authorized reviewer denied on assigned station'; END IF;
 IF public.metra_lock_authorized_station_read(reviewer,station_b,'users.station.view') IS TRUE THEN
  RAISE EXCEPTION 'reviewer unexpectedly authorized for unassigned station'; END IF;
 IF public.metra_lock_authorized_station_read(observer,station_a,'users.station.view') IS TRUE THEN
  RAISE EXCEPTION 'observer unexpectedly inherited station directory permission'; END IF;
 IF public.metra_lock_authorized_station_read(NULL,station_a,'users.station.view') IS TRUE THEN
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
 RAISE NOTICE 'PASS: actor-bound directory, audit and review queue; station isolation and fail-closed checks';
END $$;
