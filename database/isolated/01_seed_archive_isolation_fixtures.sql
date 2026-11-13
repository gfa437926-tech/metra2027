-- Two stations under the SAME authority. Synthetic UUIDs only.
BEGIN;

TRUNCATE permission_grant_audit, permission_grants, station_assignments,
  authority_memberships, metra_role_permissions, metra_account_states,
  station_catalogue, meteorological_authorities, countries, auth.users,
  metra_role_catalogue RESTART IDENTITY CASCADE;

INSERT INTO auth.users (id, email) VALUES
  ('11111111-1111-1111-1111-111111111111', 'observer@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'reviewer@example.test');

INSERT INTO public.countries (id, is_active) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

INSERT INTO public.meteorological_authorities (id, country_id, is_active) VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

-- Station A and Station B — same authority
INSERT INTO public.station_catalogue (id, owner_authority_id, country_id) VALUES
  ('aaaaaaaa-0001-0001-0001-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('aaaaaaaa-0002-0002-0002-000000000002', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

INSERT INTO public.metra_role_catalogue (role_code, is_active) VALUES
  ('observer', true),
  ('station_head', true);

-- Role allow-list: archive access is an explicit permission grant; observer role alone is not enough
INSERT INTO public.metra_role_permissions (role_code, permission_code) VALUES
  ('observer', 'observation.create'),
  ('station_head', 'observation.review'),
  ('station_head', 'observation.approve');

INSERT INTO public.metra_account_states (user_id, account_state) VALUES
  ('11111111-1111-1111-1111-111111111111', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'active');

INSERT INTO public.authority_memberships (user_id, authority_id, approval_status) VALUES
  ('11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'approved'),
  ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'approved');

-- Observer is assigned to station A only; station B remains outside the actor's station scope.
INSERT INTO public.station_assignments (user_id, station_id, authority_id, assignment_role_code) VALUES
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0001-0001-0001-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'observer'),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-0001-0001-0001-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'station_head');

-- Explicit archive grant ONLY for station A for observer
INSERT INTO public.permission_grants (user_id, permission_code, authority_id, requested_by, approved_by, reviewed_at, reason)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'observation.archive.read',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  now(),
  'isolated archive authorization fixture'
);

INSERT INTO public.permission_grant_audit (grant_id, action, actor_user_id, station_id, permission_code, note)
SELECT id, 'granted', '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-0001-0001-0001-000000000001', permission_code, 'isolated authority archive grant; assignment binds station A'
FROM public.permission_grants
WHERE user_id = '11111111-1111-1111-1111-111111111111'
  AND permission_code = 'observation.archive.read';

COMMIT;
