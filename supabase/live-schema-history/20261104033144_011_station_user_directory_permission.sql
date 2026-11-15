INSERT INTO public.metra_role_permissions (role_code,permission_code)
VALUES ('station_head','users.station.view'),('system_admin','users.station.view')
ON CONFLICT (role_code,permission_code) DO NOTHING;