create table public.metra_observation_records (
 id uuid primary key default gen_random_uuid(),
 source_system text not null,
 source_table text not null,
 source_record_id text not null,
 station_id uuid null references public.station_catalogue(id) on delete restrict,
 station_name_source text,
 observation_type text not null,
 observed_at timestamptz,
 payload jsonb not null,
 is_demo boolean not null default false,
 imported_at timestamptz not null default now(),
 constraint metra_observation_source_identity_uq unique(source_system,source_table,source_record_id),
 constraint metra_observation_payload_object_ck check (jsonb_typeof(payload)='object'),
 constraint metra_observation_type_ck check (observation_type in
  ('daily','hourly','climate','soil','agricultural','phenomenon','fieldclimate'))
);
create index metra_observation_station_time_idx
 on public.metra_observation_records(station_id,observed_at desc)
 where station_id is not null;
create index metra_observation_type_time_idx
 on public.metra_observation_records(observation_type,observed_at desc);
create index metra_observation_source_idx
 on public.metra_observation_records(source_system,source_table);
alter table public.metra_observation_records enable row level security;
revoke all on public.metra_observation_records from anon, authenticated;
create policy metra_observation_records_deny_all
 on public.metra_observation_records as restrictive for all to anon,authenticated
 using(false) with check(false);
comment on table public.metra_observation_records is
 'Normalized immutable import envelope for legacy meteorological observations. Raw meteorological payload excludes user identity/contact/authentication fields. Pending backend-only access.';
