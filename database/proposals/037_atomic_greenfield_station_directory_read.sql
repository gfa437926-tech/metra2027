-- PROPOSAL ONLY — atomic, actor-bound greenfield station directory read.
-- Do not apply to hosted Supabase without explicit owner approval.
-- Service-role access is restricted to this RPC; caller identity is derived by .NET from validated JWT sub.

CREATE OR REPLACE FUNCTION catalog.get_station_directory_for_actor(
  p_actor_user_id uuid,
  p_limit integer DEFAULT 250,
  p_offset integer DEFAULT 0,
  p_station_type_code text DEFAULT NULL
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
DECLARE
  v_now timestamptz := statement_timestamp();
BEGIN
  IF p_actor_user_id IS NULL OR p_actor_user_id = '00000000-0000-0000-0000-000000000000'::uuid
     OR p_limit IS NULL OR p_limit < 1 OR p_limit > 500
     OR p_offset IS NULL OR p_offset < 0
     OR (p_station_type_code IS NOT NULL AND
         (length(p_station_type_code) NOT BETWEEN 1 AND 64 OR
          p_station_type_code !~ '^[A-Za-z0-9_-]+$')) THEN
    RAISE EXCEPTION 'invalid_station_directory_request' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
    'id', s.id::text,
    'station_code', s.station_code,
    'name_ar', s.name_ar,
    'name_en', s.name_en,
    'wmo_identifier', s.wmo_identifier,
    'station_type_code', st.type_code,
    'station_type_name_ar', st.name_ar,
    'station_type_name_en', st.name_en,
    'approval_status', s.approval_status,
    'operational_status', s.operational_status,
    'latitude', loc.latitude,
    'longitude', loc.longitude,
    'elevation_m', s.elevation_m,
    'timezone_name', s.timezone_name,
    'location_source', loc.location_source,
    'horizontal_accuracy_m', loc.horizontal_accuracy_m
  )
  FROM catalog.stations s
  JOIN catalog.station_types st ON st.id = s.station_type_id AND st.is_active = true
  LEFT JOIN LATERAL (
    SELECT l.latitude, l.longitude, l.location_source, l.horizontal_accuracy_m
    FROM catalog.station_locations l
    WHERE l.station_id = s.id AND l.valid_to IS NULL
    ORDER BY l.valid_from DESC, l.id DESC
    LIMIT 1
  ) loc ON true
  JOIN LATERAL (
    SELECT true AS is_authorized
    FROM iam.user_profiles up
    JOIN iam.memberships m ON m.user_id = up.user_id
    JOIN iam.organizations org ON org.id = m.organization_id AND org.organization_state = 'active'
    JOIN iam.role_assignments ra ON ra.membership_id = m.id
    JOIN iam.roles r ON r.id = ra.role_id AND r.role_state = 'active'
    JOIN iam.role_permissions rp ON rp.role_id = r.id
    JOIN iam.permissions perm ON perm.id = rp.permission_id
    WHERE up.user_id = p_actor_user_id
      AND up.profile_state = 'active'
      AND m.membership_state = 'active'
      AND m.valid_from <= v_now AND (m.valid_to IS NULL OR m.valid_to > v_now)
      AND ra.assignment_state = 'active'
      AND ra.valid_from <= v_now AND (ra.valid_to IS NULL OR ra.valid_to > v_now)
      AND (
        (ra.scope_type = 'station'
          AND ra.station_id = s.id
          AND ra.organization_id = s.owner_organization_id
          AND m.organization_id = s.owner_organization_id
          AND perm.permission_code = 'stations.read')
        OR
        (ra.scope_type = 'global'
          AND ra.organization_id IS NULL AND ra.unit_id IS NULL AND ra.station_id IS NULL
          AND r.role_code IN ('auditor', 'network_department_head')
          AND perm.permission_code = 'stations.read_all')
      )
    ORDER BY ra.id
    LIMIT 1
    FOR SHARE OF up, m, org, ra, r, rp, perm
  ) authorization ON authorization.is_authorized
  WHERE s.approval_status = 'approved'
    AND s.operational_status IN ('active','temporarily_closed')
    AND (p_station_type_code IS NULL OR st.type_code = p_station_type_code)
  ORDER BY s.station_code
  LIMIT p_limit OFFSET p_offset;
END;
$function$;

REVOKE ALL ON FUNCTION catalog.get_station_directory_for_actor(uuid, integer, integer, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION catalog.get_station_directory_for_actor(uuid, integer, integer, text)
  TO service_role;

COMMENT ON FUNCTION catalog.get_station_directory_for_actor(uuid, integer, integer, text) IS
  'Atomic station directory projection. Station assignments see only their station; auditor/network_department_head require active global assignment and stations.read_all. Service-role only; actor UUID must come from validated JWT sub.';
