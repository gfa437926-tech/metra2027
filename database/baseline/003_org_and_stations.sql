-- METRA baseline 003 — countries, authorities, station catalogue skeleton
-- No legacy METRA OLD station imports.

CREATE TABLE IF NOT EXISTS public.countries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  iso2 char(2),
  name_en text,
  name_ar text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.meteorological_authorities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id uuid NOT NULL REFERENCES public.countries(id) ON DELETE RESTRICT,
  code text,
  name_en text,
  name_ar text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.station_catalogue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_authority_id uuid NOT NULL REFERENCES public.meteorological_authorities(id) ON DELETE RESTRICT,
  country_id uuid NOT NULL REFERENCES public.countries(id) ON DELETE RESTRICT,
  station_code text,
  name_en text,
  name_ar text,
  latitude numeric,
  longitude numeric,
  elevation_m numeric,
  approval_status text NOT NULL DEFAULT 'approved'
    CHECK (approval_status IN ('pending','approved','rejected','suspended')),
  operational_status text NOT NULL DEFAULT 'active'
    CHECK (operational_status IN ('active','inactive','decommissioned')),
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.station_catalogue IS
  'Authoritative NEW catalogue skeleton. Not populated from METRA OLD in baseline.';
