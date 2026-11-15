-- Disposable IAM/catalogue fixture for testing proposal 036 only.
-- This is intentionally a minimal contract fixture, not a canonical schema replay.
-- Run only against an isolated PostgreSQL database; never against hosted Supabase.
CREATE SCHEMA IF NOT EXISTS iam;
CREATE SCHEMA IF NOT EXISTS catalog;

CREATE TABLE iam.user_profiles (
  user_id uuid PRIMARY KEY,
  profile_state text NOT NULL DEFAULT 'active' CHECK (profile_state IN ('active','suspended','closed'))
);
CREATE TABLE iam.organizations (id uuid PRIMARY KEY);
CREATE TABLE iam.memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES iam.user_profiles(user_id) ON DELETE RESTRICT,
  organization_id uuid NOT NULL REFERENCES iam.organizations(id) ON DELETE RESTRICT,
  membership_state text NOT NULL DEFAULT 'pending' CHECK (membership_state IN ('pending','active','suspended','ended','rejected')),
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  CHECK (valid_to IS NULL OR valid_to > valid_from),
  UNIQUE (id, organization_id)
);
CREATE TABLE iam.roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_code text NOT NULL UNIQUE,
  name_ar text NOT NULL,
  name_en text NOT NULL,
  description text,
  is_system_role boolean NOT NULL DEFAULT false,
  is_assignable boolean NOT NULL DEFAULT true,
  is_requestable boolean NOT NULL DEFAULT false,
  role_state text NOT NULL DEFAULT 'active' CHECK (role_state IN ('active','inactive')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE iam.permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  permission_code text NOT NULL UNIQUE,
  name_ar text NOT NULL,
  name_en text NOT NULL,
  description text,
  permission_domain text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE iam.role_permissions (
  role_id uuid NOT NULL REFERENCES iam.roles(id) ON DELETE RESTRICT,
  permission_id uuid NOT NULL REFERENCES iam.permissions(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, permission_id)
);
CREATE TABLE catalog.stations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_organization_id uuid NOT NULL,
  UNIQUE (id, owner_organization_id)
);
CREATE TABLE iam.role_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membership_id uuid NOT NULL,
  organization_id uuid,
  unit_id uuid,
  station_id uuid,
  role_id uuid NOT NULL REFERENCES iam.roles(id) ON DELETE RESTRICT,
  scope_type text NOT NULL CHECK (scope_type IN ('global','organization','unit','station')),
  assignment_state text NOT NULL DEFAULT 'pending' CHECK (assignment_state IN ('pending','active','suspended','revoked','expired')),
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  CHECK (valid_to IS NULL OR valid_to > valid_from),
  CHECK ((scope_type='global' AND organization_id IS NULL AND unit_id IS NULL AND station_id IS NULL) OR
         (scope_type='organization' AND organization_id IS NOT NULL AND unit_id IS NULL AND station_id IS NULL) OR
         (scope_type='unit' AND organization_id IS NOT NULL AND unit_id IS NOT NULL AND station_id IS NULL) OR
         (scope_type='station' AND organization_id IS NOT NULL AND unit_id IS NULL AND station_id IS NOT NULL)),
  FOREIGN KEY (membership_id, organization_id) REFERENCES iam.memberships(id, organization_id) ON DELETE RESTRICT,
  FOREIGN KEY (station_id, organization_id) REFERENCES catalog.stations(id, owner_organization_id) ON DELETE RESTRICT
);

INSERT INTO iam.roles (role_code,name_ar,name_en,is_system_role,is_assignable,is_requestable)
VALUES ('auditor','مدقق','Auditor',true,true,false);
INSERT INTO iam.permissions (permission_code,name_ar,name_en,permission_domain) VALUES
 ('alerts.read','قراءة التنبيهات','Read alerts','alerts'),
 ('audit.read','قراءة التدقيق','Read audit','audit'),
 ('forecasts.read','قراءة التنبؤات','Read forecasts','forecasts'),
 ('observations.read_station','قراءة أرصاد المحطة','Read station observations','observations'),
 ('stations.read','قراءة المحطات','Read stations','stations');
INSERT INTO iam.role_permissions (role_id,permission_id)
SELECT r.id,p.id FROM iam.roles r CROSS JOIN iam.permissions p
WHERE r.role_code='auditor' AND p.permission_code IN
 ('alerts.read','audit.read','forecasts.read','observations.read_station','stations.read');
