-- =============================================================================
-- ops_station_isolation_pg_test.sql
-- RUN ONLY against an EMPTY disposable PostgreSQL database.
-- DO NOT run against production, staged hosted Supabase, or the legacy METRA DB.
--
-- Expected environment (set by the harness, not hard-coded secrets):
--   METRA_OPS_TEST_DATABASE_URL  -> local ephemeral Postgres
--
-- This script:
--   1) Creates minimal station-scoped tables + session GUC helpers (self-contained
--      for isolation proof; not a substitute for production migrations).
--   2) Seeds station A / station B rows.
--   3) Forces app.station_id / app.user_id and asserts cross-station reads return 0.
--   4) Fails hard (RAISE EXCEPTION) on any cross-station leakage.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Session context helpers mirroring NpgsqlOpsSession SET LOCAL usage.
CREATE OR REPLACE FUNCTION metra_test_set_station_context(p_user_id uuid, p_station_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config('app.user_id', p_user_id::text, true);
  PERFORM set_config('app.station_id', p_station_id::text, true);
END;
$$;

CREATE TABLE IF NOT EXISTS metra_test_stations (
  id uuid PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS metra_test_equipment_faults (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id uuid NOT NULL REFERENCES metra_test_stations(id),
  title text NOT NULL
);

CREATE TABLE IF NOT EXISTS metra_test_support_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id uuid NOT NULL REFERENCES metra_test_stations(id),
  title text NOT NULL
);

ALTER TABLE metra_test_equipment_faults ENABLE ROW LEVEL SECURITY;
ALTER TABLE metra_test_support_incidents ENABLE ROW LEVEL SECURITY;

-- Deny by default for the table owner in this test role model:
DROP POLICY IF EXISTS metra_test_faults_station_isolation ON metra_test_equipment_faults;
CREATE POLICY metra_test_faults_station_isolation ON metra_test_equipment_faults
  FOR ALL
  USING (station_id::text = current_setting('app.station_id', true))
  WITH CHECK (station_id::text = current_setting('app.station_id', true));

DROP POLICY IF EXISTS metra_test_support_station_isolation ON metra_test_support_incidents;
CREATE POLICY metra_test_support_station_isolation ON metra_test_support_incidents
  FOR ALL
  USING (station_id::text = current_setting('app.station_id', true))
  WITH CHECK (station_id::text = current_setting('app.station_id', true));

-- Force RLS even for table owner during this test session.
ALTER TABLE metra_test_equipment_faults FORCE ROW LEVEL SECURITY;
ALTER TABLE metra_test_support_incidents FORCE ROW LEVEL SECURITY;

DO $$
DECLARE
  station_a uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  station_b uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  user_a uuid := '11111111-1111-4111-8111-111111111111';
  user_b uuid := '22222222-2222-4222-8222-222222222222';
  fault_a uuid;
  fault_b uuid;
  incident_a uuid;
  incident_b uuid;
  cnt integer;
BEGIN
  INSERT INTO metra_test_stations(id) VALUES (station_a), (station_b)
  ON CONFLICT DO NOTHING;

  INSERT INTO metra_test_equipment_faults(id, station_id, title)
  VALUES (gen_random_uuid(), station_a, 'fault-a')
  RETURNING id INTO fault_a;
  INSERT INTO metra_test_equipment_faults(id, station_id, title)
  VALUES (gen_random_uuid(), station_b, 'fault-b')
  RETURNING id INTO fault_b;

  INSERT INTO metra_test_support_incidents(id, station_id, title)
  VALUES (gen_random_uuid(), station_a, 'incident-a')
  RETURNING id INTO incident_a;
  INSERT INTO metra_test_support_incidents(id, station_id, title)
  VALUES (gen_random_uuid(), station_b, 'incident-b')
  RETURNING id INTO incident_b;

  -- Seed while bypassing RLS as owner without FORCE would still see all;
  -- FORCE is on, so temporarily disable for seed completeness if needed.
  -- With FORCE RLS, owner is also subject to policies — set context per insert.
  -- Re-seed under explicit contexts to satisfy WITH CHECK.
  DELETE FROM metra_test_equipment_faults;
  DELETE FROM metra_test_support_incidents;

  PERFORM metra_test_set_station_context(user_a, station_a);
  INSERT INTO metra_test_equipment_faults(station_id, title) VALUES (station_a, 'fault-a');
  INSERT INTO metra_test_support_incidents(station_id, title) VALUES (station_a, 'incident-a');

  PERFORM metra_test_set_station_context(user_b, station_b);
  INSERT INTO metra_test_equipment_faults(station_id, title) VALUES (station_b, 'fault-b');
  INSERT INTO metra_test_support_incidents(station_id, title) VALUES (station_b, 'incident-b');

  -- User A context: only station A visible.
  PERFORM metra_test_set_station_context(user_a, station_a);

  SELECT count(*) INTO cnt FROM metra_test_equipment_faults;
  IF cnt <> 1 THEN
    RAISE EXCEPTION 'FAULT_ISOLATION_FAIL: expected 1 fault for station A, got %', cnt;
  END IF;

  SELECT count(*) INTO cnt FROM metra_test_equipment_faults WHERE station_id = station_b;
  IF cnt <> 0 THEN
    RAISE EXCEPTION 'FAULT_CROSS_STATION_FAIL: station A context saw % station B faults', cnt;
  END IF;

  SELECT count(*) INTO cnt FROM metra_test_support_incidents;
  IF cnt <> 1 THEN
    RAISE EXCEPTION 'SUPPORT_ISOLATION_FAIL: expected 1 incident for station A, got %', cnt;
  END IF;

  SELECT count(*) INTO cnt FROM metra_test_support_incidents WHERE station_id = station_b;
  IF cnt <> 0 THEN
    RAISE EXCEPTION 'SUPPORT_CROSS_STATION_FAIL: station A context saw % station B incidents', cnt;
  END IF;

  -- Switch to station B: must not see station A.
  PERFORM metra_test_set_station_context(user_b, station_b);

  SELECT count(*) INTO cnt FROM metra_test_equipment_faults WHERE station_id = station_a;
  IF cnt <> 0 THEN
    RAISE EXCEPTION 'FAULT_CROSS_STATION_FAIL: station B context saw % station A faults', cnt;
  END IF;

  SELECT count(*) INTO cnt FROM metra_test_support_incidents WHERE station_id = station_a;
  IF cnt <> 0 THEN
    RAISE EXCEPTION 'SUPPORT_CROSS_STATION_FAIL: station B context saw % station A incidents', cnt;
  END IF;

  -- Empty station context must not leak rows.
  PERFORM set_config('app.station_id', '', true);
  PERFORM set_config('app.user_id', '', true);
  SELECT count(*) INTO cnt FROM metra_test_equipment_faults;
  IF cnt <> 0 THEN
    RAISE EXCEPTION 'EMPTY_CONTEXT_FAIL: faults visible without station context (% rows)', cnt;
  END IF;

  RAISE NOTICE 'ops_station_isolation_pg_test: PASSED';
END $$;

ROLLBACK;
