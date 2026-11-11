-- METRA baseline 006 — registration + station audit log skeletons
-- Minimal columns to satisfy later incremental migrations' FKs/joins.
-- Full workflow columns may be extended by later migrations.

CREATE TABLE IF NOT EXISTS public.metra_user_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  display_name text,
  phone text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.registration_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  requested_station_id uuid REFERENCES public.station_catalogue(id),
  requested_role_code text REFERENCES public.metra_role_catalogue(role_code),
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.registration_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id uuid NOT NULL REFERENCES public.registration_requests(id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES auth.users(id),
  action_code text NOT NULL,
  from_status text,
  to_status text,
  note text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.station_audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  station_id uuid NOT NULL REFERENCES public.station_catalogue(id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES auth.users(id),
  event_type text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);
