CREATE TABLE public.metra_role_permissions (
    role_code text NOT NULL REFERENCES public.metra_role_catalogue(role_code) ON UPDATE RESTRICT ON DELETE RESTRICT,
    permission_code text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (role_code, permission_code),
    CONSTRAINT metra_role_permissions_permission_code_nonempty CHECK (length(btrim(permission_code)) > 0)
);

COMMENT ON TABLE public.metra_role_permissions IS
'Explicit allow-list mapping between METRA roles and permission codes. Empty by default: permissions remain denied until reviewed and explicitly configured.';

ALTER TABLE public.metra_role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.metra_role_permissions FORCE ROW LEVEL SECURITY;

CREATE POLICY metra_role_permissions_deny_client_access
ON public.metra_role_permissions
FOR ALL
TO anon, authenticated
USING (false)
WITH CHECK (false);

REVOKE ALL ON TABLE public.metra_role_permissions FROM PUBLIC, anon, authenticated, metra_api_runtime;

CREATE INDEX metra_role_permissions_permission_idx
ON public.metra_role_permissions (permission_code, role_code);

CREATE OR REPLACE FUNCTION public.metra_user_has_station_permission(
    p_user_id uuid,
    p_station_id uuid,
    p_permission_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
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
          AND permission.approval_status = 'approved'
          AND permission.revoked_at IS NULL
          AND permission.valid_from <= now()
          AND (permission.valid_to IS NULL OR permission.valid_to > now())
    ), FALSE);
$function$;

REVOKE ALL ON FUNCTION public.metra_user_has_station_permission(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.metra_user_has_station_permission(uuid, uuid, text) TO service_role;