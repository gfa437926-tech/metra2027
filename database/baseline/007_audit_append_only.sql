-- METRA baseline 007 — append-only audit protections

CREATE TABLE IF NOT EXISTS public.permission_grant_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  grant_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('granted','revoked','modified')),
  actor_user_id uuid REFERENCES auth.users(id),
  station_id uuid REFERENCES public.station_catalogue(id),
  permission_code text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  note text
);

CREATE TABLE IF NOT EXISTS public.authority_access_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  target_kind text NOT NULL CHECK (target_kind IN ('membership','permission_grant')),
  target_id uuid NOT NULL,
  authority_id uuid NOT NULL REFERENCES public.meteorological_authorities(id) ON DELETE RESTRICT,
  subject_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  action_code text NOT NULL CHECK (action_code IN ('requested','approved','rejected','revoked')),
  from_status text,
  to_status text NOT NULL,
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 5 AND 2000),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  occurred_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE OR REPLACE FUNCTION public.reject_append_only_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'audit table is append-only' USING ERRCODE = '55000';
END;
$$;

DROP TRIGGER IF EXISTS permission_grant_audit_immutable ON public.permission_grant_audit;
CREATE TRIGGER permission_grant_audit_immutable
BEFORE UPDATE OR DELETE ON public.permission_grant_audit
FOR EACH ROW EXECUTE FUNCTION public.reject_append_only_audit_mutation();

DROP TRIGGER IF EXISTS authority_access_audit_immutable ON public.authority_access_audit_events;
CREATE TRIGGER authority_access_audit_immutable
BEFORE UPDATE OR DELETE ON public.authority_access_audit_events
FOR EACH ROW EXECUTE FUNCTION public.reject_append_only_audit_mutation();

DROP TRIGGER IF EXISTS registration_audit_immutable ON public.registration_audit_events;
CREATE TRIGGER registration_audit_immutable
BEFORE UPDATE OR DELETE ON public.registration_audit_events
FOR EACH ROW EXECUTE FUNCTION public.reject_append_only_audit_mutation();

DROP TRIGGER IF EXISTS station_audit_log_immutable ON public.station_audit_log;
CREATE TRIGGER station_audit_log_immutable
BEFORE UPDATE OR DELETE ON public.station_audit_log
FOR EACH ROW EXECUTE FUNCTION public.reject_append_only_audit_mutation();
