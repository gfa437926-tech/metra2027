-- METRA baseline 005 — accounts, memberships, assignments, permission grants

CREATE TABLE IF NOT EXISTS public.metra_account_states (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  account_state text NOT NULL DEFAULT 'active'
    CHECK (account_state IN ('active','disabled','pending','locked')),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.authority_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  authority_id uuid NOT NULL REFERENCES public.meteorological_authorities(id) ON DELETE RESTRICT,
  membership_role_code text REFERENCES public.metra_role_catalogue(role_code),
  approval_status text NOT NULL DEFAULT 'approved'
    CHECK (approval_status IN ('pending','approved','rejected','revoked')),
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.station_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  station_id uuid NOT NULL REFERENCES public.station_catalogue(id) ON DELETE RESTRICT,
  authority_id uuid NOT NULL REFERENCES public.meteorological_authorities(id) ON DELETE RESTRICT,
  assignment_role_code text NOT NULL REFERENCES public.metra_role_catalogue(role_code),
  approval_status text NOT NULL DEFAULT 'approved'
    CHECK (approval_status IN ('pending','approved','rejected','revoked')),
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.permission_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  permission_code text NOT NULL,
  authority_id uuid REFERENCES public.meteorological_authorities(id) ON DELETE RESTRICT,
  -- Station binding: required for observation.archive.read (enforced by CHECK below).
  station_id uuid REFERENCES public.station_catalogue(id) ON DELETE RESTRICT,
  approval_status text NOT NULL DEFAULT 'approved'
    CHECK (approval_status IN ('pending','approved','rejected','revoked')),
  approved_at timestamptz,
  approved_by uuid REFERENCES auth.users(id),
  reviewed_at timestamptz,
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT permission_grants_archive_requires_station CHECK (
    permission_code <> 'observation.archive.read'
    OR station_id IS NOT NULL
  )
);

COMMENT ON COLUMN public.permission_grants.station_id IS
  'For observation.archive.read MUST be non-null (table CHECK). Other permissions may use authority-scoped grants pending separate review. Production RPC station bind is a separate approved change (proposal 031).';
