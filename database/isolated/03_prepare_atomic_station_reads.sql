-- Synthetic fixtures required by C9.4 actor-bound read RPC tests.
ALTER TABLE public.metra_role_catalogue ADD COLUMN IF NOT EXISTS name_ar text;
ALTER TABLE public.metra_role_catalogue ADD COLUMN IF NOT EXISTS name_en text;
ALTER TABLE public.metra_account_states ADD COLUMN IF NOT EXISTS state_reason text;
CREATE TABLE IF NOT EXISTS public.metra_user_profiles (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id), first_name text, father_name text, last_name text, phone text
);
CREATE TABLE IF NOT EXISTS public.station_audit_log (
 id bigserial PRIMARY KEY, entity_type text NOT NULL, entity_id uuid NOT NULL, action text NOT NULL,
 actor_id uuid, reason text, occurred_at timestamptz NOT NULL DEFAULT now(),
 before_data jsonb NOT NULL DEFAULT '{}'::jsonb, after_data jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE IF NOT EXISTS public.metra_observations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), station_id uuid NOT NULL REFERENCES public.station_catalogue(id),
 created_by uuid NOT NULL REFERENCES auth.users(id), observation_type text NOT NULL,
 observed_at timestamptz NOT NULL, payload jsonb NOT NULL, status text NOT NULL,
 submitted_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
UPDATE public.metra_role_catalogue SET name_ar='راصد',name_en='Observer' WHERE role_code='observer';
UPDATE public.metra_role_catalogue SET name_ar='رئيس محطة',name_en='Station Head' WHERE role_code='station_head';
INSERT INTO public.metra_role_permissions(role_code,permission_code)
VALUES ('station_head','users.station.view') ON CONFLICT DO NOTHING;
INSERT INTO public.permission_grants(user_id,permission_code,authority_id,requested_by,approved_by,reviewed_at,reason) VALUES
 ('22222222-2222-2222-2222-222222222222','users.station.view','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111',now(),'isolated read grant'),
 ('22222222-2222-2222-2222-222222222222','observation.review','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111',now(),'isolated read grant');
INSERT INTO public.metra_user_profiles(user_id,first_name,father_name,last_name,phone) VALUES
 ('11111111-1111-1111-1111-111111111111','Observer','Test','One','000000001'),
 ('22222222-2222-2222-2222-222222222222','Reviewer','Test','Two','000000002');
INSERT INTO public.station_audit_log(entity_type,entity_id,action,actor_id,reason,before_data,after_data)
VALUES ('station','aaaaaaaa-0001-0001-0001-000000000001','updated',
 '22222222-2222-2222-2222-222222222222','isolated fixture','{}'::jsonb,'{"operational_status":"active"}'::jsonb);
INSERT INTO public.metra_observations(station_id,created_by,observation_type,observed_at,payload,status,submitted_at)
VALUES ('aaaaaaaa-0001-0001-0001-000000000001','11111111-1111-1111-1111-111111111111',
 'hourly',now(),'{"dryTemp":"20.0"}'::jsonb,'submitted',now());


CREATE TABLE IF NOT EXISTS public.metra_observation_records (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 source_system text NOT NULL,
 source_table text NOT NULL,
 source_record_id text NOT NULL,
 station_id uuid REFERENCES public.station_catalogue(id),
 station_name_source text,
 observation_type text NOT NULL,
 observed_at timestamptz,
 payload jsonb NOT NULL,
 is_demo boolean NOT NULL DEFAULT false,
 imported_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(source_system,source_table,source_record_id)
);
CREATE INDEX IF NOT EXISTS metra_observation_station_time_idx
 ON public.metra_observation_records(station_id,observed_at DESC)
 WHERE station_id IS NOT NULL;

INSERT INTO public.metra_observation_records
 (id,source_system,source_table,source_record_id,station_id,station_name_source,observation_type,observed_at,payload,is_demo,imported_at)
VALUES
 ('eeeeeeee-0001-0001-0001-000000000001','legacy-test','hourly_reports','hourly-A-new',
  'aaaaaaaa-0001-0001-0001-000000000001','Station A legacy name','hourly','2026-01-02T00:00:00Z',
  '{"utc_time":"00","dry_temp":"+20.0","raw_data":"private-original","station_name":"private-name","user_station":"legacy-user-station","status":"approved"}'::jsonb,
  false,'2026-01-02T00:05:00Z'),
 ('eeeeeeee-0001-0001-0001-000000000002','legacy-test','daily_reports','daily-A-old',
  'aaaaaaaa-0001-0001-0001-000000000001','Station A legacy name','daily','2026-01-01T00:00:00Z',
  '{"report_type":"24h","min_temperature":"05.0","max_temperature":"20.0"}'::jsonb,
  false,'2026-01-01T00:05:00Z'),
 ('eeeeeeee-0002-0002-0002-000000000003','legacy-test','hourly_reports','hourly-B',
  'aaaaaaaa-0002-0002-0002-000000000002','Station B legacy name','hourly','2026-01-03T00:00:00Z',
  '{"utc_time":"00","dry_temp":"+21.0"}'::jsonb,
  false,'2026-01-03T00:05:00Z'),
 ('eeeeeeee-0000-0000-0000-000000000004','legacy-test','hourly_reports','hourly-unlinked',
  NULL,NULL,'hourly','2026-01-04T00:00:00Z',
  '{"utc_time":"00","dry_temp":"+22.0"}'::jsonb,
  false,'2026-01-04T00:05:00Z')
ON CONFLICT (source_system,source_table,source_record_id) DO NOTHING;
