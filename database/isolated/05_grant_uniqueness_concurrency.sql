-- Isolated grant uniqueness + concurrency probe (requires Path N schema + C2.5 unique indexes applied).
\set ON_ERROR_STOP on

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'permission_grants_active_station_unique'
  ) THEN
    RAISE EXCEPTION 'missing permission_grants_active_station_unique — apply c25_readiness/04 first';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE indexname = 'permission_grants_active_authority_unique'
  ) THEN
    RAISE EXCEPTION 'missing permission_grants_active_authority_unique — apply c25_readiness/04 first';
  END IF;
END $$;

-- Seed minimal subjects if absent
INSERT INTO auth.users(id) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01')
ON CONFLICT DO NOTHING;
INSERT INTO countries(id, is_active) VALUES ('cccccccc-cccc-cccc-cccc-cccccccccc01', true)
ON CONFLICT DO NOTHING;
INSERT INTO meteorological_authorities(id, country_id, authority_code, is_active)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01', 'cccccccc-cccc-cccc-cccc-cccccccccc01', 'C3AUTH', true)
ON CONFLICT DO NOTHING;
INSERT INTO station_catalogue(id, owner_authority_id, country_id, approval_status, operational_status, is_demo)
VALUES ('11111111-1111-1111-1111-111111111101', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01', 'cccccccc-cccc-cccc-cccc-cccccccccc01', 'approved', 'active', false)
ON CONFLICT DO NOTHING;

-- Clean prior probe rows
DELETE FROM permission_grants
 WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'
   AND permission_code IN ('observation.archive.read', 'observation.create');

INSERT INTO permission_grants(user_id, permission_code, authority_id, station_id, approval_status)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01',
  'observation.archive.read',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
  '11111111-1111-1111-1111-111111111101',
  'approved'
);

-- Second active station grant must fail
DO $$
BEGIN
  BEGIN
    INSERT INTO permission_grants(user_id, permission_code, authority_id, station_id, approval_status)
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01',
      'observation.archive.read',
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
      '11111111-1111-1111-1111-111111111101',
      'approved'
    );
    RAISE EXCEPTION 'FAIL: duplicate active station grant accepted';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS: duplicate active station grant rejected (23505)';
  END;
END $$;

INSERT INTO permission_grants(user_id, permission_code, authority_id, station_id, approval_status)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01',
  'observation.create',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
  NULL,
  'approved'
);

DO $$
BEGIN
  BEGIN
    INSERT INTO permission_grants(user_id, permission_code, authority_id, station_id, approval_status)
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01',
      'observation.create',
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
      NULL,
      'approved'
    );
    RAISE EXCEPTION 'FAIL: duplicate active authority grant accepted';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'PASS: duplicate active authority grant rejected (23505)';
  END;
END $$;

-- Revoke then re-grant station archive
UPDATE permission_grants
   SET revoked_at = statement_timestamp()
 WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'
   AND permission_code = 'observation.archive.read'
   AND revoked_at IS NULL;

INSERT INTO permission_grants(user_id, permission_code, authority_id, station_id, approval_status)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01',
  'observation.archive.read',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01',
  '11111111-1111-1111-1111-111111111101',
  'approved'
);

DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM permission_grants
   WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'
     AND permission_code = 'observation.archive.read'
     AND station_id = '11111111-1111-1111-1111-111111111101'
     AND revoked_at IS NULL
     AND approval_status = 'approved';
  IF n <> 1 THEN
    RAISE EXCEPTION 'FAIL: expected 1 active archive grant after regrant, got %', n;
  END IF;
  RAISE NOTICE 'PASS: regrant after revoke yields single active row';
  RAISE NOTICE 'ALL GRANT UNIQUENESS TESTS PASSED';
END $$;
