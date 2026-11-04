-- Enforce authority membership, role allow-list and individual grant in the
-- same transaction as station-catalogue review. Station operations remain
-- station-scoped; network catalogue review is scoped to the station owner.
CREATE OR REPLACE FUNCTION public.metra_user_has_station_owner_authority_permission(
    p_user_id uuid,
    p_station_id uuid,
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
          FROM public.station_catalogue AS station
          JOIN public.meteorological_authorities AS authority
            ON authority.id = station.owner_authority_id
           AND authority.country_id = station.country_id
          JOIN public.countries AS country
            ON country.id = station.country_id
         WHERE station.id = p_station_id
           AND station.is_demo = FALSE
           AND authority.is_active = TRUE
           AND country.is_active = TRUE
           AND public.metra_user_has_authority_permission(
               p_user_id, authority.id, p_permission_code
           ) IS TRUE
    ), FALSE);
$function$;

REVOKE ALL ON FUNCTION public.metra_user_has_station_owner_authority_permission(uuid, uuid, text)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.metra_user_has_station_owner_authority_permission(uuid, uuid, text)
TO service_role;

-- Replace the service-only entry point with an authority-scoped transactional
-- gate. Locks prevent membership/grant revocation from racing the review.
CREATE OR REPLACE FUNCTION public.decide_station_catalogue_review(
    p_station_id uuid,
    p_expected_status text,
    p_actor_user_id uuid,
    p_decision text,
    p_reason text,
    p_occurred_at timestamp with time zone
)
RETURNS TABLE(result_status text, resulting_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private
AS $function$
DECLARE
    v_authority_id uuid;
    v_now timestamptz := clock_timestamp();
BEGIN
    IF p_station_id IS NULL OR p_actor_user_id IS NULL
       OR p_expected_status IS DISTINCT FROM 'pending'
       OR p_decision IS NULL
       OR p_decision NOT IN ('approved', 'rejected', 'changes_requested')
       OR p_reason IS NULL
       OR length(trim(p_reason)) NOT BETWEEN 5 AND 2000
       OR p_reason <> trim(p_reason)
       OR p_reason ~ '[[:cntrl:]]'
       OR p_occurred_at IS NULL THEN
        RAISE EXCEPTION 'invalid_station_review_request' USING ERRCODE = '22023';
    END IF;

    SELECT station.owner_authority_id
      INTO v_authority_id
      FROM public.station_catalogue AS station
      JOIN public.meteorological_authorities AS authority
        ON authority.id = station.owner_authority_id
       AND authority.country_id = station.country_id
      JOIN public.countries AS country
        ON country.id = station.country_id
     WHERE station.id = p_station_id
       AND station.is_demo = FALSE
       AND authority.is_active = TRUE
       AND country.is_active = TRUE
     FOR UPDATE OF station
     FOR SHARE OF authority, country;

    IF v_authority_id IS NULL THEN
        RAISE EXCEPTION 'station_authority_not_available' USING ERRCODE = '42501';
    END IF;

    PERFORM 1
      FROM public.metra_account_states AS account
     WHERE account.user_id = p_actor_user_id
       AND account.account_state = 'active'
     FOR SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'reviewer_account_not_active' USING ERRCODE = '42501';
    END IF;

    PERFORM 1
      FROM public.authority_memberships AS membership
      JOIN public.metra_role_catalogue AS role
        ON role.role_code = membership.membership_role_code
       AND role.is_active = TRUE
      JOIN public.metra_role_permissions AS role_permission
        ON role_permission.role_code = role.role_code
       AND role_permission.permission_code = 'stations.catalogue.review'
     WHERE membership.user_id = p_actor_user_id
       AND membership.authority_id = v_authority_id
       AND membership.approval_status = 'approved'
       AND membership.valid_from <= v_now
       AND (membership.valid_to IS NULL OR membership.valid_to > v_now)
     FOR SHARE OF membership, role, role_permission;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'station_review_authority_membership_denied' USING ERRCODE = '42501';
    END IF;

    PERFORM 1
      FROM public.permission_grants AS permission
     WHERE permission.user_id = p_actor_user_id
       AND permission.permission_code = 'stations.catalogue.review'
       AND permission.approval_status = 'approved'
       AND permission.revoked_at IS NULL
       AND permission.valid_from <= v_now
       AND (permission.valid_to IS NULL OR permission.valid_to > v_now)
     FOR SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'station_review_permission_denied' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
      SELECT decision.result_status, decision.resulting_status
        FROM private.decide_station_catalogue_review(
            p_station_id, p_expected_status, p_actor_user_id,
            p_decision, p_reason, p_occurred_at
        ) AS decision;
END;
$function$;

REVOKE ALL ON FUNCTION public.decide_station_catalogue_review(
    uuid, text, uuid, text, text, timestamp with time zone
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.decide_station_catalogue_review(
    uuid, text, uuid, text, text, timestamp with time zone
) TO service_role;
