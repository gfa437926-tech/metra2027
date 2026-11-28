-- Authority-scoped authorization is intentionally separate from station-scoped
-- authorization. This RPC is callable only by the trusted API runtime.
CREATE OR REPLACE FUNCTION public.metra_user_has_authority_permission(
    p_user_id uuid,
    p_authority_id uuid,
    p_permission_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
    SELECT COALESCE(EXISTS (
        SELECT 1
          FROM public.metra_account_states AS account
          JOIN public.meteorological_authorities AS authority
            ON authority.id = p_authority_id
          JOIN public.countries AS country
            ON country.id = authority.country_id
          JOIN public.authority_memberships AS membership
            ON membership.user_id = account.user_id
           AND membership.authority_id = authority.id
          JOIN public.metra_role_catalogue AS role
            ON role.role_code = membership.membership_role_code
           AND role.is_active = TRUE
          JOIN public.metra_role_permissions AS role_permission
            ON role_permission.role_code = role.role_code
           AND role_permission.permission_code = p_permission_code
          JOIN public.permission_grants AS permission
            ON permission.user_id = account.user_id
           AND permission.permission_code = p_permission_code
         WHERE account.user_id = p_user_id
           AND account.account_state = 'active'
           AND authority.is_active = TRUE
           AND country.is_active = TRUE
           AND membership.approval_status = 'approved'
           AND membership.valid_from <= statement_timestamp()
           AND (membership.valid_to IS NULL OR membership.valid_to > statement_timestamp())
           AND permission.approval_status = 'approved'
           AND permission.revoked_at IS NULL
           AND permission.valid_from <= statement_timestamp()
           AND (permission.valid_to IS NULL OR permission.valid_to > statement_timestamp())
    ), FALSE);
$function$;

COMMENT ON FUNCTION public.metra_user_has_authority_permission(uuid, uuid, text)
IS 'Fail-closed authority-scope permission check. Requires active account, active authority and country, approved current membership with active role mapping, and an approved current individual permission grant. No national/global bypass. Trusted API runtime only.';

REVOKE ALL ON FUNCTION public.metra_user_has_authority_permission(uuid, uuid, text)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.metra_user_has_authority_permission(uuid, uuid, text)
TO service_role;
