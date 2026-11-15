-- Allow Network Director to review station catalogue records.
-- Effective access still requires an approved, time-valid individual grant and station assignment.
INSERT INTO public.metra_role_permissions (role_code, permission_code)
VALUES ('network_director', 'stations.catalogue.review')
ON CONFLICT (role_code, permission_code) DO NOTHING;