-- METRA baseline 004 — roles and permission catalogue

CREATE TABLE IF NOT EXISTS public.metra_role_catalogue (
  role_code text PRIMARY KEY,
  name_ar text,
  name_en text,
  description_ar text,
  description_en text,
  is_requestable boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  display_order int NOT NULL DEFAULT 100
);

CREATE TABLE IF NOT EXISTS public.metra_permission_codes (
  code text PRIMARY KEY,
  description text,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.metra_role_permissions (
  role_code text NOT NULL REFERENCES public.metra_role_catalogue(role_code) ON DELETE CASCADE,
  permission_code text NOT NULL,
  PRIMARY KEY (role_code, permission_code)
);

-- Catalogue entry for archive (grant still required per station; role allow-list alone is insufficient)
INSERT INTO public.metra_permission_codes (code, description) VALUES
  ('observation.archive.read', 'Explicit station-scoped observation archive read')
ON CONFLICT (code) DO NOTHING;
