-- Deterministic synthetic source/target fixture for the full comparison runner.
-- Applied identically to two disposable PostgreSQL databases in CI.
INSERT INTO public.station_catalogue
  (id, is_demo, approval_status, operational_status)
VALUES
  ('00000000-0000-4000-8000-000000000001', false, 'pending', 'unverified'),
  ('00000000-0000-4000-8000-000000000002', false, 'pending', 'unverified');

INSERT INTO public.station_coordinates (id, station_id)
VALUES ('00000000-0000-4000-8000-000000000101',
        '00000000-0000-4000-8000-000000000001');

CREATE TYPE public.compare_fixture_state AS ENUM ('queued', 'complete');
CREATE INDEX auth_fk_fixture_note_idx ON public.auth_fk_fixture(note);
CREATE VIEW public.compare_fixture_view AS
  SELECT id, note FROM public.auth_fk_fixture ORDER BY id;

ALTER TABLE public.auth_fk_fixture ENABLE ROW LEVEL SECURITY;
CREATE POLICY compare_fixture_authenticated_select
  ON public.auth_fk_fixture
  FOR SELECT TO authenticated
  USING (true);

CREATE TABLE private.compare_fixture_private (
  id integer PRIMARY KEY,
  payload text NOT NULL,
  state public.compare_fixture_state NOT NULL
);
INSERT INTO private.compare_fixture_private(id, payload, state)
VALUES (1, 'synthetic-private-payload', 'queued');

SELECT setval('public.authority_access_audit_events_id_seq', 10, true);
SELECT setval('public.metra_equipment_fault_audit_events_id_seq', 11, true);
SELECT setval('public.metra_observation_audit_events_id_seq', 12, true);
SELECT setval('public.metra_support_incident_audit_events_id_seq', 13, true);
SELECT setval('public.registration_audit_events_id_seq', 14, true);
SELECT setval('public.station_audit_log_id_seq', 42, true);
