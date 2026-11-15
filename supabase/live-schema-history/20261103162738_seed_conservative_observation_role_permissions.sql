INSERT INTO public.metra_role_permissions (role_code, permission_code)
VALUES
    ('observer', 'observation.create'),
    ('observer', 'observation.edit_own_draft'),
    ('observer', 'observation.submit'),
    ('station_head', 'observation.review'),
    ('station_head', 'observation.return_for_correction'),
    ('station_auditor', 'observation.review'),
    ('station_auditor', 'observation.return_for_correction'),
    ('chief_auditor', 'observation.approve'),
    ('chief_auditor', 'observation.return_for_correction')
ON CONFLICT (role_code, permission_code) DO NOTHING;