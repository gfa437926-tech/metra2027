-- PROPOSAL ONLY — station-bound archive authorization RPC.
-- DO NOT APPLY TO HOSTED SUPABASE without explicit human approval.
--
-- The existing generic metra_user_has_station_permission RPC grants authority-scoped
-- permissions and cannot prove that observation.archive.read was granted for this
-- exact station. The API archive endpoints therefore call this dedicated RPC and
-- fail closed (403) until this proposal is reviewed and explicitly applied.

CREATE OR REPLACE FUNCTION public.metra_user_has_station_archive_permission(
    p_user_id uuid,
    p_station_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
SELECT COALESCE(EXISTS(
  SELECT 1
  FROM public.metra_account_states AS ac
  JOIN public.station_catalogue AS s
    ON s.id = p_station_id
  JOIN public.meteorological_authorities AS a
    ON a.id = s.owner_authority_id
   AND a.country_id = s.country_id
  JOIN public.countries AS c
    ON c.id = s.country_id
  JOIN public.authority_memberships AS m
    ON m.user_id = ac.user_id
   AND m.authority_id = s.owner_authority_id
  JOIN public.station_assignments AS sa
    ON sa.user_id = ac.user_id
   AND sa.station_id = s.id
   AND sa.authority_id = s.owner_authority_id
  JOIN public.metra_role_catalogue AS r
    ON r.role_code = sa.assignment_role_code
   AND r.is_active
  JOIN public.metra_role_permissions AS rp
    ON rp.role_code = r.role_code
   AND rp.permission_code = 'observation.archive.read'
  JOIN public.permission_grants AS g
    ON g.user_id = ac.user_id
   AND g.authority_id = s.owner_authority_id
   AND g.permission_code = 'observation.archive.read'
  WHERE ac.user_id = p_user_id
    AND ac.account_state = 'active'
    AND s.approval_status = 'approved'
    AND s.operational_status = 'active'
    AND s.is_demo = false
    AND a.is_active
    AND c.is_active
    AND m.approval_status = 'approved'
    AND m.valid_from <= statement_timestamp()
    AND (m.valid_to IS NULL OR m.valid_to > statement_timestamp())
    AND sa.approval_status = 'approved'
    AND sa.valid_from <= statement_timestamp()
    AND (sa.valid_to IS NULL OR sa.valid_to > statement_timestamp())
    AND g.approval_status = 'approved'
    AND g.revoked_at IS NULL
    AND g.valid_from <= statement_timestamp()
    AND (g.valid_to IS NULL OR g.valid_to > statement_timestamp())
), false);
$function$;

REVOKE ALL ON FUNCTION public.metra_user_has_station_archive_permission(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.metra_user_has_station_archive_permission(uuid, uuid) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.metra_user_has_station_archive_permission(uuid, uuid) TO service_role;

COMMENT ON FUNCTION public.metra_user_has_station_archive_permission(uuid, uuid) IS
  'PROPOSAL ONLY: requires active station assignment and explicit observation.archive.read grant bound to the exact station_id.';
