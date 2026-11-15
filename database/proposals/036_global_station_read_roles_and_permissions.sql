-- PROPOSAL ONLY — METRA global station-read role and permission catalogue.
-- Do not apply to hosted Supabase without explicit owner approval.
-- Intended for Path N / disposable PostgreSQL verification only.

BEGIN;

INSERT INTO iam.permissions (permission_code, name_ar, name_en, description, permission_domain)
VALUES
  ('stations.read_all', 'قراءة جميع المحطات', 'Read all stations', 'Read approved station directory entries across station scopes.', 'stations'),
  ('observations.read_all', 'قراءة أرصاد جميع المحطات', 'Read observations across all stations', 'Read station observations across station scopes; read-only.', 'observations'),
  ('audit.read_all', 'قراءة سجلات تدقيق جميع المحطات', 'Read audit records across all stations', 'Read station-scoped audit records across station scopes; read-only.', 'audit'),
  ('forecasts.read_all', 'قراءة تنبؤات جميع المحطات', 'Read forecasts across all stations', 'Read approved forecast projections across station scopes; read-only.', 'forecasts'),
  ('alerts.read_all', 'قراءة تنبيهات جميع المحطات', 'Read alerts across all stations', 'Read station alerts across station scopes; read-only.', 'alerts'),
  ('recorder.read_all', 'قراءة مسجلات جميع المحطات', 'Read recorder records across all stations', 'Read recorder archive metadata and approved digitization results across station scopes; read-only.', 'recorders'),
  ('instruments.read_all', 'قراءة أجهزة جميع المحطات', 'Read instruments across all stations', 'Read instrument inventory and calibration records across station scopes; read-only.', 'instruments')
ON CONFLICT (permission_code) DO NOTHING;

INSERT INTO iam.roles (role_code, name_ar, name_en, description, is_system_role, is_assignable, is_requestable, role_state)
VALUES (
  'network_department_head',
  'رئيس دائرة الشبكات',
  'Head of Network Department',
  'System role with explicitly scoped cross-station read permissions. No implicit create, update, approval, identity or platform administration rights.',
  true, false, false, 'active'
)
ON CONFLICT (role_code) DO NOTHING;

-- Grant only explicit read_all permissions to the auditor and network-head roles.
-- The assignment itself must separately be approved with iam.role_assignments.scope_type = 'global'.
INSERT INTO iam.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM iam.roles r
JOIN iam.permissions p ON p.permission_code IN (
  'stations.read_all',
  'observations.read_all',
  'audit.read_all',
  'forecasts.read_all',
  'alerts.read_all',
  'recorder.read_all',
  'instruments.read_all'
)
WHERE r.role_code IN ('auditor', 'network_department_head')
  AND NOT EXISTS (
    SELECT 1 FROM iam.role_permissions existing
    WHERE existing.role_id = r.id AND existing.permission_id = p.id
  );

COMMIT;

-- Deliberately not included:
-- * no user role assignment or membership activation;
-- * no table grants, RLS policies, service identities or API credentials;
-- * no data insertion into catalog.stations;
-- * no write/approve/manage permissions;
-- * no change to existing auditor permissions or role assignability.