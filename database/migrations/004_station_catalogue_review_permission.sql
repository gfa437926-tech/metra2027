-- Allow the Network Director role to request station-catalogue review actions.
-- An approved, time-valid individual permission_grants row is still mandatory.
-- This is an insert-only allow-list migration; it does not rewrite existing grants.
INSERT INTO public.metra_role_permissions (role_code, permission_code)
VALUES ('network_director', 'stations.catalogue.review')
ON CONFLICT (role_code, permission_code) DO NOTHING;
