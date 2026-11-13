-- METRA baseline 008 — core indexes

CREATE INDEX IF NOT EXISTS idx_station_catalogue_authority
  ON public.station_catalogue (owner_authority_id);

CREATE INDEX IF NOT EXISTS idx_station_assignments_user_station
  ON public.station_assignments (user_id, station_id);

CREATE INDEX IF NOT EXISTS idx_station_assignments_station
  ON public.station_assignments (station_id);

CREATE INDEX IF NOT EXISTS idx_authority_memberships_user_authority
  ON public.authority_memberships (user_id, authority_id);

CREATE INDEX IF NOT EXISTS idx_permission_grants_user_code
  ON public.permission_grants (user_id, permission_code);

CREATE INDEX IF NOT EXISTS idx_permission_grants_station_code
  ON public.permission_grants (station_id, permission_code)
  WHERE station_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_permission_grant_audit_grant
  ON public.permission_grant_audit (grant_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_station_audit_log_station_time
  ON public.station_audit_log (station_id, occurred_at DESC);
