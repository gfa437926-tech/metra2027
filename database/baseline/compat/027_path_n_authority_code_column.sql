-- Path N compatibility for migration 027
-- Target: database/migrations/027_add_authority_catalogue_read_model.sql
-- Official API field name in get_authority_catalogue JSON: authority_code
-- Baseline historically used meteorological_authorities.code
-- Resolution: rename code -> authority_code when needed; add is_national if missing.
-- Do NOT keep both columns. Backend C# does not reference authority_code directly (JSON only).
-- Path H: if hosted already has authority_code, this is a no-op rename guard.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='meteorological_authorities'
      AND column_name='code'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='meteorological_authorities'
      AND column_name='authority_code'
  ) THEN
    ALTER TABLE public.meteorological_authorities RENAME COLUMN code TO authority_code;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='meteorological_authorities'
      AND column_name='authority_code'
  ) THEN
    ALTER TABLE public.meteorological_authorities ADD COLUMN authority_code text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='meteorological_authorities'
      AND column_name='is_national'
  ) THEN
    ALTER TABLE public.meteorological_authorities ADD COLUMN is_national boolean NOT NULL DEFAULT false;
  END IF;
END $$;
