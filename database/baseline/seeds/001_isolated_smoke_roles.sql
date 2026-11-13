-- Optional isolated smoke roles only — not operational catalogue data.
INSERT INTO public.metra_role_catalogue (role_code, name_en, name_ar, is_requestable, is_active, display_order)
VALUES
  ('observer', 'Weather Observer', 'راصد جوي', true, true, 10),
  ('station_head', 'Station Manager', 'رئيس محطة', false, true, 20)
ON CONFLICT (role_code) DO NOTHING;

INSERT INTO public.metra_role_permissions (role_code, permission_code) VALUES
  ('observer', 'observation.archive.read'),
  ('observer', 'observation.create'),
  ('station_head', 'observation.review'),
  ('station_head', 'observation.approve')
ON CONFLICT DO NOTHING;
