-- REAL TEST HARNESS — psql only.
-- Strictly restricted to a fresh disposable database named metra_ops_test.
-- It refuses non-empty data tables, verifies FORCE RLS, runs the existing
-- cross-station scenarios, and rolls every fixture back.
-- Never point this script at production, hosted Supabase, or the legacy DB.

\set ON_ERROR_STOP on

DO $guard$
DECLARE
  v_table text;
  v_has_rows boolean;
  v_rls_enabled boolean;
  v_rls_forced boolean;
  v_policy_count integer;
BEGIN
  IF current_database() <> 'metra_ops_test' THEN
    RAISE EXCEPTION 'REFUSED: expected disposable database metra_ops_test, got %', current_database();
  END IF;

  IF current_setting('transaction_read_only') = 'on' THEN
    RAISE EXCEPTION 'REFUSED: test connection is read-only';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'metra_ops_faults') THEN
    RAISE EXCEPTION 'Missing required role metra_ops_faults; apply reviewed migrations only to the disposable DB first';
  END IF;

  FOREACH v_table IN ARRAY ARRAY[
    'auth.users',
    'public.station_catalogue',
    'public.metra_equipment_faults',
    'public.metra_equipment_fault_audit_events',
    'public.metra_support_incidents',
    'public.metra_support_incident_audit_events'
  ] LOOP
    IF to_regclass(v_table) IS NULL THEN
      RAISE EXCEPTION 'Missing required relation %. Apply reviewed schema migrations to the disposable DB first', v_table;
    END IF;
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM %s LIMIT 1)', to_regclass(v_table))
      INTO v_has_rows;
    IF v_has_rows THEN
      RAISE EXCEPTION 'REFUSED: %.% is not empty; use a fresh disposable database', v_table, current_database();
    END IF;
  END LOOP;

  FOREACH v_table IN ARRAY ARRAY[
    'public.metra_equipment_faults',
    'public.metra_equipment_fault_audit_events',
    'public.metra_support_incidents',
    'public.metra_support_incident_audit_events'
  ] LOOP
    SELECT c.relrowsecurity, c.relforcerowsecurity
      INTO v_rls_enabled, v_rls_forced
      FROM pg_class c
      WHERE c.oid = to_regclass(v_table);
    IF NOT coalesce(v_rls_enabled, false) OR NOT coalesce(v_rls_forced, false) THEN
      RAISE EXCEPTION 'REFUSED: RLS and FORCE RLS must both be enabled on %', v_table;
    END IF;

    SELECT count(*) INTO v_policy_count
      FROM pg_policies p
      WHERE (p.schemaname || '.' || p.tablename) = v_table
        AND p.roles::text[] @> ARRAY['metra_ops_faults'];
    IF v_policy_count = 0 THEN
      RAISE EXCEPTION 'REFUSED: no metra_ops_faults RLS policy found on %', v_table;
    END IF;
  END LOOP;
END
$guard$;

-- The included suite seeds two stations/users and checks SELECT/UPDATE isolation,
-- audit immutability, valid transition audit, rollback, and support incident isolation.
-- The outer transaction guarantees all test fixtures are discarded.
BEGIN;
\ir equipment_fault_npgsql_isolation.sql
ROLLBACK;

\echo 'ops_station_isolation_pg_test: PASS (all fixtures rolled back; disposable DB only)'
