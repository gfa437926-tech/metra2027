-- Isolated test schema for METRA Stage C.
-- NOT for hosted Supabase. Synthetic IDs only. No production data.
BEGIN;

-- Supabase API roles required by the station-bound RPC proposal in isolated CI.
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END;
$roles$;

CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS auth.users (
  id uuid PRIMARY KEY,
  email text
);

CREATE TABLE IF NOT EXISTS public.countries (
  id uuid PRIMARY KEY,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.meteorological_authorities (
  id uuid PRIMARY KEY,
  country_id uuid NOT NULL REFERENCES public.countries(id),
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.station_catalogue (
  id uuid PRIMARY KEY,
  owner_authority_id uuid NOT NULL REFERENCES public.meteorological_authorities(id),
  country_id uuid NOT NULL REFERENCES public.countries(id),
  approval_status text NOT NULL DEFAULT 'approved',
  operational_status text NOT NULL DEFAULT 'active',
  is_demo boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.metra_account_states (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id),
  account_state text NOT NULL DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS public.authority_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  authority_id uuid NOT NULL REFERENCES public.meteorological_authorities(id),
  approval_status text NOT NULL DEFAULT 'approved',
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz
);

CREATE TABLE IF NOT EXISTS public.metra_role_catalogue (
  role_code text PRIMARY KEY,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.station_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  station_id uuid NOT NULL REFERENCES public.station_catalogue(id),
  authority_id uuid NOT NULL REFERENCES public.meteorological_authorities(id),
  assignment_role_code text NOT NULL REFERENCES public.metra_role_catalogue(role_code),
  approval_status text NOT NULL DEFAULT 'approved',
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz
);

CREATE TABLE IF NOT EXISTS public.metra_role_permissions (
  role_code text NOT NULL REFERENCES public.metra_role_catalogue(role_code),
  permission_code text NOT NULL,
  PRIMARY KEY (role_code, permission_code)
);

CREATE TABLE IF NOT EXISTS public.permission_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  permission_code text NOT NULL,
  authority_id uuid REFERENCES public.meteorological_authorities(id),
  approval_status text NOT NULL DEFAULT 'approved',
  requested_by uuid NOT NULL REFERENCES auth.users(id),
  approved_by uuid REFERENCES auth.users(id),
  reviewed_at timestamptz,
  reason text NOT NULL DEFAULT 'isolated test grant',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  revoked_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.permission_grant_audit (
  id bigserial PRIMARY KEY,
  grant_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('granted','revoked','modified')),
  actor_user_id uuid,
  station_id uuid,
  permission_code text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  note text
);

CREATE OR REPLACE FUNCTION public.reject_permission_grant_audit_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'permission_grant_audit is append-only' USING ERRCODE = '55000';
END;
$$;

DROP TRIGGER IF EXISTS permission_grant_audit_immutable ON public.permission_grant_audit;
CREATE TRIGGER permission_grant_audit_immutable
BEFORE UPDATE OR DELETE ON public.permission_grant_audit
FOR EACH ROW EXECUTE FUNCTION public.reject_permission_grant_audit_mutation();

-- Station-scoped archive predicate matching approved Stage B policy:
-- explicit grant for THIS station + active assignment + role allow-list entry + active account.
CREATE OR REPLACE FUNCTION public.metra_user_has_station_permission(
    p_user_id uuid,
    p_station_id uuid,
    p_permission_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $function$
    SELECT COALESCE(EXISTS (
        SELECT 1
        FROM public.metra_account_states AS account
        JOIN public.station_catalogue AS station
          ON station.id = p_station_id
        JOIN public.meteorological_authorities AS authority
          ON authority.id = station.owner_authority_id
         AND authority.country_id = station.country_id
        JOIN public.countries AS country
          ON country.id = station.country_id
        JOIN public.authority_memberships AS membership
          ON membership.user_id = account.user_id
         AND membership.authority_id = station.owner_authority_id
        JOIN public.station_assignments AS assignment
          ON assignment.user_id = account.user_id
         AND assignment.station_id = station.id
         AND assignment.authority_id = station.owner_authority_id
        JOIN public.metra_role_catalogue AS role
          ON role.role_code = assignment.assignment_role_code
         AND role.is_active = TRUE
        JOIN public.metra_role_permissions AS role_permission
          ON role_permission.role_code = role.role_code
         AND role_permission.permission_code = p_permission_code
        JOIN public.permission_grants AS permission
          ON permission.user_id = account.user_id
         AND permission.permission_code = p_permission_code
         AND permission.revoked_at IS NULL
         AND permission.valid_from <= now()
         AND (permission.valid_to IS NULL OR permission.valid_to > now())
        WHERE account.user_id = p_user_id
          AND account.account_state = 'active'
          AND station.approval_status = 'approved'
          AND station.operational_status = 'active'
          AND station.is_demo = FALSE
          AND authority.is_active = TRUE
          AND country.is_active = TRUE
          AND membership.approval_status = 'approved'
          AND membership.valid_from <= now()
          AND (membership.valid_to IS NULL OR membership.valid_to > now())
          AND assignment.approval_status = 'approved'
          AND assignment.valid_from <= now()
          AND (assignment.valid_to IS NULL OR assignment.valid_to > now())
    ), false);
$function$;

COMMIT;
